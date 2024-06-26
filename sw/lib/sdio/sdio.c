#include "sdio.h"
#include "crc.h"
#include <hardware/clocks.h>
#include <hardware/dma.h>
#include <pico/stdlib.h>
#include <sdio.pio.h>
#include <string.h>

#define SDIO_PIO pio0
#define SDIO_CLK_SM 0
#define SDIO_CMD_SM 1
#define SDIO_DAT_SM 2
#define SDIO_DMA0 0
#define SDIO_DMA1 1

#define INITIAL_CLOCK_DIV 100 // 1.25MHz
#define RECV_BUF_CNT 256

static struct {
    uint32_t cmd_timeout_ms;
    bool resources_claimed;

    uint pio_offset_tx;
    uint pio_offset_rx;

    pio_sm_config pio_cfg_cmd;
    pio_sm_config pio_cfg_recv;
    pio_sm_config pio_cfg_send;

    uint32_t nblocks;
    uint32_t checksumed;
    uint64_t crc[RECV_BUF_CNT];
    struct {
        uint8_t *data;
        uint32_t len;
    } control_blocks[RECV_BUF_CNT * 2];

    uint32_t wr_crc_buf[3];
    uint64_t wr_next_crc;
    const uint8_t *wr_buf;
    uint32_t wr_curr_block;
    uint32_t block_size;
} sdio;

void sdio_init(uint sck, uint cmd, uint d0, uint32_t cmd_timeout_ms)
{
    sdio.cmd_timeout_ms = cmd_timeout_ms;
    if (!sdio.resources_claimed) {
        pio_sm_claim(SDIO_PIO, SDIO_CLK_SM);
        pio_sm_claim(SDIO_PIO, SDIO_CMD_SM);
        pio_sm_claim(SDIO_PIO, SDIO_DAT_SM);
        dma_channel_claim(SDIO_DMA0);
        dma_channel_claim(SDIO_DMA1);
        sdio.resources_claimed = true;
    }

    pio_clear_instruction_memory(SDIO_PIO);

    pio_gpio_init(SDIO_PIO, sck);
    pio_gpio_init(SDIO_PIO, cmd);
    pio_gpio_init(SDIO_PIO, d0);
    pio_gpio_init(SDIO_PIO, d0 + 1);
    pio_gpio_init(SDIO_PIO, d0 + 2);
    pio_gpio_init(SDIO_PIO, d0 + 3);
    gpio_pull_up(cmd);
    gpio_pull_up(d0);
    gpio_pull_up(d0 + 1);
    gpio_pull_up(d0 + 2);
    gpio_pull_up(d0 + 3);
    pio_sm_set_consecutive_pindirs(SDIO_PIO, SDIO_CLK_SM, sck, 1, true);
    pio_sm_set_consecutive_pindirs(SDIO_PIO, SDIO_CMD_SM, cmd, 1, false);
    pio_sm_set_consecutive_pindirs(SDIO_PIO, SDIO_DAT_SM, d0, 4, false);

    // Clock program
    uint offset = pio_add_program(SDIO_PIO, &sdio_clk_program);
    pio_sm_config cfg = sdio_clk_program_get_default_config(offset);
    sm_config_set_sideset_pins(&cfg, sck);
    sm_config_set_clkdiv_int_frac(&cfg, INITIAL_CLOCK_DIV, 0);
    pio_sm_init(SDIO_PIO, SDIO_CLK_SM, offset, &cfg);
    pio_sm_set_enabled(SDIO_PIO, SDIO_CLK_SM, true);

    sdio.pio_offset_tx = pio_add_program(SDIO_PIO, &sdio_tx_program);
    sdio.pio_offset_rx = pio_add_program(SDIO_PIO, &sdio_rx_program);

    // State machine configuration for sending commands
    sdio.pio_cfg_cmd = sdio_tx_program_get_default_config(sdio.pio_offset_tx);
    sm_config_set_out_pins(&sdio.pio_cfg_cmd, cmd, 1);
    sm_config_set_set_pins(&sdio.pio_cfg_cmd, cmd, 1);
    sm_config_set_in_pins(&sdio.pio_cfg_cmd, cmd);
    sm_config_set_out_shift(&sdio.pio_cfg_cmd, false, true, 32);
    sm_config_set_in_shift(&sdio.pio_cfg_cmd, false, true, 32);
    sm_config_set_clkdiv_int_frac(&sdio.pio_cfg_cmd, INITIAL_CLOCK_DIV, 0);

    // State machine configuration for receiving data blocks
    sdio.pio_cfg_recv = sdio_rx_program_get_default_config(sdio.pio_offset_rx);
    sm_config_set_in_pins(&sdio.pio_cfg_recv, d0);
    sm_config_set_out_shift(&sdio.pio_cfg_recv, false, true, 32);
    sm_config_set_in_shift(&sdio.pio_cfg_recv, false, true, 32);
    sm_config_set_clkdiv_int_frac(&sdio.pio_cfg_recv, INITIAL_CLOCK_DIV, 0);

    // State machine configuration for sending data blocks
    sdio.pio_cfg_send = sdio_tx_program_get_default_config(sdio.pio_offset_tx);
    sm_config_set_out_pins(&sdio.pio_cfg_send, d0, 4);
    sm_config_set_set_pins(&sdio.pio_cfg_send, d0, 4);
    sm_config_set_in_pins(&sdio.pio_cfg_send, d0);
    sm_config_set_out_shift(&sdio.pio_cfg_send, false, true, 32);
    sm_config_set_in_shift(&sdio.pio_cfg_send, false, false, 32);
    sm_config_set_clkdiv_int_frac(&sdio.pio_cfg_send, INITIAL_CLOCK_DIV, 0);

    // We have a synchronous interface. Therefore, input triggers can be disabled.
    SDIO_PIO->input_sync_bypass |= (1u << sck) | (1u << cmd)
        | (1u << d0) | (1u << (d0 + 1)) | (1u << (d0 + 2)) | (1u << (d0 + 3));
}

void sdio_set_clkdiv(uint16_t div)
{
    pio_sm_set_clkdiv_int_frac(SDIO_PIO, SDIO_CLK_SM, div, 0);
    pio_sm_clkdiv_restart(SDIO_PIO, SDIO_CLK_SM);

    sm_config_set_clkdiv_int_frac(&sdio.pio_cfg_cmd, div, 0);
    sm_config_set_clkdiv_int_frac(&sdio.pio_cfg_recv, div, 0);
    sm_config_set_clkdiv_int_frac(&sdio.pio_cfg_send, div, 0);
}

static sdio_err sdio_cmd(uint8_t cmd, uint32_t arg, uint8_t *resp_buf, uint8_t buf_size, uint8_t resp_bits)
{
    assert((buf_size % 4) == 0);
    assert(resp_bits != 1);
    assert(resp_bits <= (buf_size * 8));

    sdio_err rc = SDIO_ERR_OK;
    uint8_t req[] = {
        0x40 | (cmd & 0x3F),
        arg >> 24u,
        arg >> 16u,
        arg >> 8u,
        arg >> 0u
    };
    uint32_t reqw1 = 0xFF << 24u
        | 0xFF << 16u
        | req[0] << 8u
        | req[1] << 0u;
    uint32_t reqw2 = req[2] << 24u
        | req[3] << 16u
        | req[4] << 8u
        | ((crc7(req, sizeof req) << 1) | 0x01);

    pio_sm_init(SDIO_PIO, SDIO_CMD_SM, sdio.pio_offset_tx + sdio_tx_offset_send_cmd, &sdio.pio_cfg_cmd);
    // Set request and response length
    pio_sm_put(SDIO_PIO, SDIO_CMD_SM, 16 + 48 - 1);
    pio_sm_exec(SDIO_PIO, SDIO_CMD_SM, pio_encode_out(pio_x, 32));
    pio_sm_put(SDIO_PIO, SDIO_CMD_SM, resp_buf == NULL ? 0 : (resp_bits - 2));
    pio_sm_exec(SDIO_PIO, SDIO_CMD_SM, pio_encode_out(pio_y, 32));
    // Set pin to output
    pio_sm_exec(SDIO_PIO, SDIO_CMD_SM, pio_encode_set(pio_pins, 1));
    pio_sm_exec(SDIO_PIO, SDIO_CMD_SM, pio_encode_set(pio_pindirs, 1));
    // Push a request into fifo
    pio_sm_put(SDIO_PIO, SDIO_CMD_SM, reqw1);
    pio_sm_put(SDIO_PIO, SDIO_CMD_SM, reqw2);

    absolute_time_t timeout = make_timeout_time_ms(sdio.cmd_timeout_ms);
    // The state machine sends an empty response if the response is empty
    // or the size of the response is aligned to 4 bytes.
    uint to_read = buf_size + ((resp_bits % 32) == 0) * 4;
    uint bits_left = resp_bits;

    pio_sm_set_enabled(SDIO_PIO, SDIO_CMD_SM, true);

    for (int i = 0; i < to_read;) {
        if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            rc = SDIO_ERR_TIMEOUT;
            goto out;
        }
        if (pio_sm_is_rx_fifo_empty(SDIO_PIO, SDIO_CMD_SM)) {
            continue;
        }
        uint32_t w = pio_sm_get(SDIO_PIO, SDIO_CMD_SM);
        // Do not read empty response
        if (i < buf_size) {
            if (bits_left < 32) {
                w <<= 32 - bits_left;
            }
            resp_buf[i + 0] = (w >> 24u);
            resp_buf[i + 1] = (w >> 16u);
            resp_buf[i + 2] = (w >> 8u);
            resp_buf[i + 3] = (w >> 0u);
            bits_left -= 32;
        }
        i += 4;
    }
out:
    pio_sm_set_enabled(SDIO_PIO, SDIO_CMD_SM, false);
    return rc;
}

sdio_err sdio_cmd_R0(uint8_t cmd, uint32_t arg)
{
    return sdio_cmd(cmd, arg, NULL, 0, 0);
}

sdio_err sdio_cmd_R1(uint8_t cmd, uint32_t arg, uint32_t *resp)
{
    uint8_t buf[8] = {};
    sdio_err rc = sdio_cmd(cmd, arg, buf, sizeof buf, 48);
    if (rc != SDIO_ERR_OK) {
        return rc;
    }

    uint8_t crc = crc7(buf, 5);
    uint8_t actual_crc = buf[5] >> 1u;
    if (crc != actual_crc) {
        return SDIO_ERR_CRC;
    }

    if (cmd != buf[0]) {
        return SDIO_ERR_RESPONSE_CMD;
    }

    *resp = buf[1] << 24u | buf[2] << 16u | buf[3] << 8u | buf[4] << 0u;
    return SDIO_ERR_OK;
}

sdio_err sdio_cmd_R2(uint8_t cmd, uint32_t arg, uint8_t *resp)
{
    uint8_t buf[20] = {};
    sdio_err rc = sdio_cmd(cmd, arg, buf, sizeof buf, 136);
    if (rc != SDIO_ERR_OK) {
        return rc;
    }

    uint8_t crc = crc7(buf + 1, 15);
    uint8_t actual_crc = buf[16] >> 1u;
    if (crc != actual_crc) {
        return SDIO_ERR_CRC;
    }

    if (buf[0] != 0x3F) {
        return SDIO_ERR_RESPONSE_CMD;
    }
    memcpy(resp, buf + 1, 16);
    return SDIO_ERR_OK;
}

sdio_err sdio_cmd_R3(uint8_t cmd, uint32_t arg, uint32_t *resp)
{
    uint8_t buf[8] = {};
    sdio_err rc = sdio_cmd(cmd, arg, buf, sizeof buf, 48);
    if (rc != SDIO_ERR_OK) {
        return rc;
    }
    *resp = buf[1] << 24u | buf[2] << 16u | buf[3] << 8u | buf[4] << 0u;
    return SDIO_ERR_OK;
}

void sdio_stop_transfer()
{
    dma_channel_abort(SDIO_DMA0);
    dma_channel_abort(SDIO_DMA1);
    pio_sm_set_enabled(SDIO_PIO, SDIO_DAT_SM, false);
}

static uint64_t crc16_4bit(const uint8_t *buf, uint32_t len)
{
    uint64_t crc = 0;
    uint32_t pos = 0;
    while (pos < len) {
        for (int unroll = 0; unroll < 4; unroll++) {
            uint32_t data_in = buf[pos] << 24u
                | buf[pos + 1] << 16u
                | buf[pos + 2] << 8u
                | buf[pos + 3] << 0u;
            pos += 4;

            uint32_t data_out = crc >> 32;
            crc <<= 32;
            data_out ^= (data_out >> 16);
            data_out ^= (data_in >> 16);

            uint64_t xorred = data_out ^ data_in;
            crc ^= xorred;
            crc ^= xorred << (5 * 4);
            crc ^= xorred << (12 * 4);
        }
    }
    return crc;
}

void sdio_start_recv(uint8_t *buf, uint32_t block_size, uint32_t nblocks)
{
    assert(block_size % 4 == 0);
    assert(nblocks < RECV_BUF_CNT);

    sdio.nblocks = nblocks;
    sdio.checksumed = 0;
    for (int i = 0; i < nblocks; i++) {
        sdio.control_blocks[i * 2].data = buf + i * block_size;
        sdio.control_blocks[i * 2].len = block_size / 4;
        sdio.control_blocks[i * 2 + 1].data = (uint8_t *)&sdio.crc[i];
        sdio.control_blocks[i * 2 + 1].len = 2;
    }
    sdio.control_blocks[nblocks * 2].data = NULL;
    sdio.control_blocks[nblocks * 2].len = 0;

    // Configure RX DMA channel to receive data
    dma_channel_config dma = dma_channel_get_default_config(SDIO_DMA0);
    channel_config_set_bswap(&dma, true);
    channel_config_set_dreq(&dma, pio_get_dreq(SDIO_PIO, SDIO_DAT_SM, false));
    channel_config_set_read_increment(&dma, false);
    channel_config_set_write_increment(&dma, true);
    channel_config_set_chain_to(&dma, SDIO_DMA1);
    dma_channel_configure(SDIO_DMA0, &dma, NULL, &SDIO_PIO->rxf[SDIO_DAT_SM], 0, false);

    // Control channel transfers two words into the data channel's control
    // registers, then halts.
    dma = dma_channel_get_default_config(SDIO_DMA1);
    channel_config_set_read_increment(&dma, true);
    channel_config_set_write_increment(&dma, true);
    channel_config_set_ring(&dma, true, 3);
    dma_channel_configure(SDIO_DMA1, &dma, &dma_hw->ch[SDIO_DMA0].al1_write_addr, sdio.control_blocks, 2, false);

    pio_sm_init(SDIO_PIO, SDIO_DAT_SM, sdio.pio_offset_rx, &sdio.pio_cfg_recv);
    pio_sm_exec(SDIO_PIO, SDIO_DAT_SM, pio_encode_set(pio_pindirs, 0b0000));

    // Each channel receives 2 bits from the block plus 16 bits CRC
    pio_sm_put(SDIO_PIO, SDIO_DAT_SM, block_size * 2 + 16 - 1);
    pio_sm_exec(SDIO_PIO, SDIO_DAT_SM, pio_encode_out(pio_y, 32));

    // Deeper RX FIFO. Must be set after out Y
    SDIO_PIO->sm[SDIO_DAT_SM].shiftctrl |= PIO_SM0_SHIFTCTRL_FJOIN_RX_BITS;

    dma_channel_start(SDIO_DMA1);
    pio_sm_set_enabled(SDIO_PIO, SDIO_DAT_SM, true);
}

sdio_err sdio_poll_recv(uint32_t *blocks_complete)
{
    uint32_t blocks_count = (dma_hw->ch[SDIO_DMA1].read_addr - (uint32_t)&sdio.control_blocks);
    blocks_count = (blocks_count / sizeof(sdio.control_blocks[0]) - 1) / 2;

    while (sdio.checksumed < blocks_count) {
        uint64_t crc = crc16_4bit(sdio.control_blocks[sdio.checksumed * 2].data,
            sdio.control_blocks[sdio.checksumed * 2].len * 4);
        crc = __builtin_bswap64(crc);
        if (crc != sdio.crc[sdio.checksumed]) {
            sdio_stop_transfer();
            return SDIO_ERR_CRC;
        }
        sdio.checksumed++;
    }
    if (blocks_complete) {
        *blocks_complete = blocks_count;
    }
    if (blocks_count >= sdio.nblocks) {
        sdio_stop_transfer();
        return SDIO_ERR_EOF;
    }
    return SDIO_ERR_OK;
}

static void calc_outgoing_crc()
{
    assert(sdio.checksumed <= sdio.nblocks);
    if (sdio.checksumed == sdio.nblocks) {
        return;
    }
    if (sdio.checksumed <= sdio.wr_curr_block + 1) {
        sdio.wr_next_crc = crc16_4bit(sdio.wr_buf + sdio.checksumed * sdio.block_size, sdio.block_size);
        sdio.checksumed++;
    }
}

static void start_send_next_block()
{
    assert(sdio.wr_curr_block < sdio.nblocks);

    sdio.wr_crc_buf[0] = (uint32_t)(sdio.wr_next_crc >> 32);
    sdio.wr_crc_buf[1] = (uint32_t)(sdio.wr_next_crc >> 0);
    sdio.wr_crc_buf[2] = 0xFFFFFFFF; // End token

    pio_sm_init(SDIO_PIO, SDIO_DAT_SM, sdio.pio_offset_tx + sdio_tx_offset_send_dat, &sdio.pio_cfg_send);
    // Set request and response length
    pio_sm_put(SDIO_PIO, SDIO_DAT_SM, 8 + sdio.block_size * 2 + 16 + 1 - 1);
    pio_sm_exec(SDIO_PIO, SDIO_DAT_SM, pio_encode_out(pio_x, 32));
    pio_sm_put(SDIO_PIO, SDIO_DAT_SM, 4 - 1);
    pio_sm_exec(SDIO_PIO, SDIO_DAT_SM, pio_encode_out(pio_y, 32));
    // Set pins to output
    pio_sm_exec(SDIO_PIO, SDIO_DAT_SM, pio_encode_set(pio_pins, 0b1111));
    pio_sm_exec(SDIO_PIO, SDIO_DAT_SM, pio_encode_set(pio_pindirs, 0b1111));
    // Push start token
    pio_sm_put(SDIO_PIO, SDIO_DAT_SM, 0xFFFFFFF0);

    dma_channel_set_read_addr(SDIO_DMA1, sdio.wr_crc_buf, false);
    dma_channel_set_read_addr(SDIO_DMA0, sdio.wr_buf + sdio.wr_curr_block * sdio.block_size, true);
    pio_sm_set_enabled(SDIO_PIO, SDIO_DAT_SM, true);
}

void sdio_start_send(const uint8_t *buf, uint32_t block_size, uint32_t nblocks)
{
    assert(block_size % 4 == 0);

    sdio.nblocks = nblocks;
    sdio.block_size = block_size;
    sdio.wr_buf = buf;
    sdio.wr_curr_block = 0;
    sdio.checksumed = 0;

    calc_outgoing_crc();

    // Configure TX DMA channel to send data
    dma_channel_config dma = dma_channel_get_default_config(SDIO_DMA0);
    channel_config_set_read_increment(&dma, true);
    channel_config_set_write_increment(&dma, false);
    channel_config_set_dreq(&dma, pio_get_dreq(SDIO_PIO, SDIO_DAT_SM, true));
    channel_config_set_bswap(&dma, true);
    channel_config_set_chain_to(&dma, SDIO_DMA1);
    dma_channel_configure(SDIO_DMA0, &dma, &SDIO_PIO->txf[SDIO_DAT_SM], NULL, sdio.block_size / 4, false);

    // DMA channel to send the CRC
    channel_config_set_bswap(&dma, false);
    dma_channel_configure(SDIO_DMA1, &dma, &SDIO_PIO->txf[SDIO_DAT_SM], NULL, 3, false);

    start_send_next_block();
}

sdio_err sdio_poll_send(uint32_t *blocks_complete)
{
    sdio_err rc = SDIO_ERR_OK;
    if (sdio.wr_curr_block >= sdio.nblocks) {
        rc = SDIO_ERR_EOF;
        goto out;
    }

    // Idle state CRC precompute
    calc_outgoing_crc();

    // Waiting for block writing to complete
    if (pio_sm_is_rx_fifo_empty(SDIO_PIO, SDIO_DAT_SM)) {
        goto out;
    }
    pio_sm_set_enabled(SDIO_PIO, SDIO_DAT_SM, false);
    uint32_t status = pio_sm_get(SDIO_PIO, SDIO_DAT_SM);
    // Response status format: x|x|x|0|status|1
    // The status takes 3 bytes. Can take values: 010, 101, 110
    status >>= 1;
    if (status == 5) {
        rc = SDIO_ERR_CRC;
        goto out;
    } else if (status != 2) {
        rc = SDIO_ERR_WRITE;
        goto out;
    }

    sdio.wr_curr_block++;
    if (sdio.wr_curr_block >= sdio.nblocks) {
        rc = SDIO_ERR_EOF;
        goto out;
    }
    start_send_next_block();
out:
    if (rc == SDIO_ERR_EOF) {
        sdio_stop_transfer();
    }
    if ((rc == SDIO_ERR_OK || rc == SDIO_ERR_EOF) && blocks_complete != NULL) {
        *blocks_complete = sdio.wr_curr_block;
    }
    return rc;
}
