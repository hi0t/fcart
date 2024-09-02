#include "jtag.h"
#include "jtag.pio.h"
#include <hardware/clocks.h>
#include <hardware/dma.h>
#include <hardware/pio.h>

#define JTAG_PIO pio0
#define JTAG_SM 0

static struct {
    uint32_t freq;
    uint pin_tms, pin_tdi;
    uint pio_off;
    uint dma_rx, dma_tx;
    dma_channel_config dma_rx_cfg, dma_tx_cfg;
    enum tap_state state;
} jtag;

static void jtag_tms_seq(uint32_t tms, uint32_t len);
static void jtag_tdi_tdo_seq(const uint32_t *tdi, uint32_t *tdo, uint32_t len, bool last_bit);

void jtag_init(uint16_t clkdiv, uint tck, uint tms, uint tdi, uint tdo)
{
    assert(clkdiv > 1);

    jtag.freq = clock_get_hz(clk_sys) / 4 / clkdiv;
    jtag.pin_tms = tms;
    jtag.pin_tdi = tdi;

    pio_sm_claim(JTAG_PIO, JTAG_SM);
    jtag.dma_rx = dma_claim_unused_channel(true);
    jtag.dma_tx = dma_claim_unused_channel(true);

    jtag.pio_off = pio_add_program(JTAG_PIO, &jtag_program);
    pio_jtag_init(JTAG_PIO, JTAG_SM, jtag.pio_off, clkdiv, tck, tms, tdi, tdo);

    jtag.dma_rx_cfg = dma_channel_get_default_config(jtag.dma_rx);
    channel_config_set_dreq(&jtag.dma_rx_cfg, pio_get_dreq(JTAG_PIO, JTAG_SM, false));
    channel_config_set_transfer_data_size(&jtag.dma_rx_cfg, DMA_SIZE_32);
    channel_config_set_read_increment(&jtag.dma_rx_cfg, false);
    dma_channel_configure(jtag.dma_rx, &jtag.dma_rx_cfg, NULL, &JTAG_PIO->rxf[JTAG_SM], 0, false);

    jtag.dma_tx_cfg = dma_channel_get_default_config(jtag.dma_tx);
    channel_config_set_dreq(&jtag.dma_tx_cfg, pio_get_dreq(JTAG_PIO, JTAG_SM, true));
    channel_config_set_transfer_data_size(&jtag.dma_tx_cfg, DMA_SIZE_32);
    channel_config_set_write_increment(&jtag.dma_tx_cfg, false);
    dma_channel_configure(jtag.dma_tx, &jtag.dma_tx_cfg, &JTAG_PIO->txf[JTAG_SM], NULL, 0, false);

    jtag.state = RUN_TEST_IDLE;
}

void jtag_deinit()
{
    pio_sm_set_enabled(JTAG_PIO, JTAG_SM, false);
    pio_remove_program(JTAG_PIO, &jtag_program, jtag.pio_off);
    pio_sm_unclaim(JTAG_PIO, JTAG_SM);
    dma_channel_unclaim(jtag.dma_rx);
    dma_channel_unclaim(jtag.dma_tx);
}

uint32_t jtag_freq()
{
    return jtag.freq;
}

void jtag_reset()
{
    jtag_tms_seq(0xFF, 6);
    jtag.state = TEST_LOGIC_RESET;
}

void jtag_select_state(enum tap_state next_states)
{
    bool tms = 0;
    uint32_t tms_states = 0;
    uint8_t cnt = 0;
    while (next_states != jtag.state) {
        switch (jtag.state) {
        case TEST_LOGIC_RESET:
            if (next_states == TEST_LOGIC_RESET) {
                tms = 1;
            } else {
                tms = 0;
                jtag.state = RUN_TEST_IDLE;
            }
            break;
        case RUN_TEST_IDLE:
            if (next_states == RUN_TEST_IDLE) {
                tms = 0;
            } else {
                tms = 1;
                jtag.state = SELECT_DR_SCAN;
            }
            break;
        case SELECT_DR_SCAN:
            switch (next_states) {
            case CAPTURE_DR:
            case SHIFT_DR:
            case EXIT1_DR:
            case PAUSE_DR:
            case EXIT2_DR:
            case UPDATE_DR:
                tms = 0;
                jtag.state = CAPTURE_DR;
                break;
            default:
                tms = 1;
                jtag.state = SELECT_IR_SCAN;
            }
            break;
        case SELECT_IR_SCAN:
            switch (next_states) {
            case CAPTURE_IR:
            case SHIFT_IR:
            case EXIT1_IR:
            case PAUSE_IR:
            case EXIT2_IR:
            case UPDATE_IR:
                tms = 0;
                jtag.state = CAPTURE_IR;
                break;
            default:
                tms = 1;
                jtag.state = TEST_LOGIC_RESET;
            }
            break;
        case CAPTURE_DR:
            if (next_states == SHIFT_DR) {
                tms = 0;
                jtag.state = SHIFT_DR;
            } else {
                tms = 1;
                jtag.state = EXIT1_DR;
            }
            break;
        case SHIFT_DR:
            if (next_states == SHIFT_DR) {
                tms = 0;
            } else {
                tms = 1;
                jtag.state = EXIT1_DR;
            }
            break;
        case EXIT1_DR:
            switch (next_states) {
            case PAUSE_DR:
            case EXIT2_DR:
            case SHIFT_DR:
            case EXIT1_DR:
                tms = 0;
                jtag.state = PAUSE_DR;
                break;
            default:
                tms = 1;
                jtag.state = UPDATE_DR;
            }
            break;
        case PAUSE_DR:
            if (next_states == PAUSE_DR) {
                tms = 0;
            } else {
                tms = 1;
                jtag.state = EXIT2_DR;
            }
            break;
        case EXIT2_DR:
            switch (next_states) {
            case SHIFT_DR:
            case EXIT1_DR:
            case PAUSE_DR:
                tms = 0;
                jtag.state = SHIFT_DR;
                break;
            default:
                tms = 1;
                jtag.state = UPDATE_DR;
            }
            break;
        case UPDATE_DR:
        case UPDATE_IR:
            if (next_states == RUN_TEST_IDLE) {
                tms = 0;
                jtag.state = RUN_TEST_IDLE;
            } else {
                tms = 1;
                jtag.state = SELECT_DR_SCAN;
            }
            break;
            /* IR column */
        case CAPTURE_IR:
            if (next_states == SHIFT_IR) {
                tms = 0;
                jtag.state = SHIFT_IR;
            } else {
                tms = 1;
                jtag.state = EXIT1_IR;
            }
            break;
        case SHIFT_IR:
            if (next_states == SHIFT_IR) {
                tms = 0;
            } else {
                tms = 1;
                jtag.state = EXIT1_IR;
            }
            break;
        case EXIT1_IR:
            switch (next_states) {
            case PAUSE_IR:
            case EXIT2_IR:
            case SHIFT_IR:
            case EXIT1_IR:
                tms = 0;
                jtag.state = PAUSE_IR;
                break;
            default:
                tms = 1;
                jtag.state = UPDATE_IR;
            }
            break;
        case PAUSE_IR:
            if (next_states == PAUSE_IR) {
                tms = 0;
            } else {
                tms = 1;
                jtag.state = EXIT2_IR;
            }
            break;
        case EXIT2_IR:
            switch (next_states) {
            case SHIFT_IR:
            case EXIT1_IR:
            case PAUSE_IR:
                tms = 0;
                jtag.state = SHIFT_IR;
                break;
            default:
                tms = 1;
                jtag.state = UPDATE_IR;
            }
            break;
        }
        tms_states <<= 1u;
        tms_states |= tms;
        cnt++;
        assert(cnt <= 32);
    }
    uint32_t reversed = 0;
    for (uint8_t i = 0; i < cnt; i++) {
        reversed <<= 1u;
        reversed |= tms_states & 1u;
        tms_states >>= 1u;
    }
    if (cnt > 0) {
        jtag_tms_seq(reversed, cnt);
    }
}

void jtag_shift_ir(const uint32_t *tdi, uint32_t len, enum tap_state end_state)
{
    if (jtag.state != SHIFT_IR) {
        jtag_select_state(SHIFT_IR);
    }

    jtag_tdi_tdo_seq(tdi, NULL, len, end_state != SHIFT_IR);

    if (end_state != SHIFT_IR) {
        jtag.state = EXIT1_IR;
        jtag_select_state(end_state);
    }
}

void jtag_shift_dr(const uint32_t *tdi, uint32_t *tdo, uint32_t len, enum tap_state end_state)
{
    if (jtag.state != SHIFT_DR) {
        jtag_select_state(SHIFT_DR);
    }

    jtag_tdi_tdo_seq(tdi, tdo, len, end_state != SHIFT_DR);

    if (end_state != SHIFT_DR) {
        jtag.state = EXIT1_DR;
        jtag_select_state(end_state);
    }
}

void jtag_toggle_clk(uint32_t len)
{
    uint32_t tms = (jtag.state == TEST_LOGIC_RESET) ? 0xFFFFFFFFu : 0x00u;
    jtag_tms_seq(tms, len);
}

static inline uint32_t fmt_command(uint32_t bit_count, bool lastbit)
{
    uint cmd_addr = jtag.pio_off + (lastbit ? jtag_offset_lastbit : jtag_offset_common);
    return (cmd_addr << 27u) | ((bit_count - 1 - lastbit) & 0x3FFFFFFu);
}

static void jtag_tms_seq(uint32_t tms, uint32_t len)
{
    assert(len > 0);

    pio_sm_set_out_pins(JTAG_PIO, JTAG_SM, jtag.pin_tms, 1);
    pio_sm_put(JTAG_PIO, JTAG_SM, fmt_command(len, false));

    uint32_t discard;
    uint32_t nwords = (len + 31) >> 5u;
    channel_config_set_read_increment(&jtag.dma_tx_cfg, false);
    dma_channel_set_config(jtag.dma_tx, &jtag.dma_tx_cfg, false);
    channel_config_set_write_increment(&jtag.dma_rx_cfg, false);
    dma_channel_set_config(jtag.dma_rx, &jtag.dma_rx_cfg, false);

    dma_channel_transfer_from_buffer_now(jtag.dma_tx, &tms, nwords);
    dma_channel_transfer_to_buffer_now(jtag.dma_rx, &discard, nwords);
    dma_channel_wait_for_finish_blocking(jtag.dma_rx);

    if (len % 32 == 0) {
        pio_sm_get_blocking(JTAG_PIO, JTAG_SM); // Discard last push due to alignment
    }
}

static void jtag_tdi_tdo_seq(const uint32_t *tdi, uint32_t *tdo, uint32_t len, bool last_bit)
{
    assert(tdi != NULL || tdo != NULL);
    assert(len > 0);

    pio_sm_set_out_pins(JTAG_PIO, JTAG_SM, jtag.pin_tdi, 1);
    pio_sm_put(JTAG_PIO, JTAG_SM, fmt_command(len, last_bit));

    uint32_t nwords = (len + 31) >> 5u;
    uint32_t discard = 0x00;
    const uint32_t *rbuf = (tdi == NULL) ? &discard : tdi;
    uint32_t *wbuf = (tdo == NULL) ? &discard : tdo;
    channel_config_set_read_increment(&jtag.dma_tx_cfg, (tdi != NULL));
    dma_channel_set_config(jtag.dma_tx, &jtag.dma_tx_cfg, false);
    channel_config_set_write_increment(&jtag.dma_rx_cfg, (tdo != NULL));
    dma_channel_set_config(jtag.dma_rx, &jtag.dma_rx_cfg, false);

    dma_channel_transfer_from_buffer_now(jtag.dma_tx, rbuf, nwords);
    dma_channel_transfer_to_buffer_now(jtag.dma_rx, wbuf, nwords);
    dma_channel_wait_for_finish_blocking(jtag.dma_rx);

    if (len % 32 == 0) {
        pio_sm_get_blocking(JTAG_PIO, JTAG_SM); // Discard last push due to alignment
    } else if (tdo != NULL) {
        tdo[nwords - 1] >>= (nwords << 5u) - len;
    }
}
