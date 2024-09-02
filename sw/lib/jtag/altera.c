#include "altera.h"
#include "bitwise.h"
#include "jtag.h"
#include <pico/time.h>

#define IRLENGTH 10

static void shift_vir(bool reg);
static void shift_vdr(const uint32_t *tx, uint32_t *rx, uint32_t len, enum tap_state end_state);

void alt_init(uint tck, uint tms, uint tdi, uint tdo)
{
    // Clock 15.625 MHz @ 125MHz
    jtag_init(2, tck, tms, tdi, tdo);
}

void alt_deinit()
{
    jtag_deinit();
}

bool alt_scan()
{
    uint32_t id = 0;
    uint32_t cmd = 0x006;
    jtag_reset();
    jtag_shift_ir(&cmd, IRLENGTH, RUN_TEST_IDLE);
    jtag_shift_dr(NULL, &id, 32, RUN_TEST_IDLE);

    //       EP4CE6/10CL006           10CL025
    return (id == 0x20f10dd) || (id == 0x20f30dd);
}

void alt_reset()
{
    uint32_t cmd = 0x001;
    jtag_select_state(TEST_LOGIC_RESET);
    jtag_shift_ir(&cmd, IRLENGTH, RUN_TEST_IDLE);
    jtag_toggle_clk(1);
    jtag_select_state(TEST_LOGIC_RESET);
}

bool alt_program_mem(alt_reader_cb cb)
{
    uint32_t cmd;
    uint32_t period = 1.0e9 / jtag_freq();

    // SIR 10 TDI (002);
    cmd = 0x002;
    jtag_shift_ir(&cmd, IRLENGTH, PAUSE_IR);

    // RUNTEST IDLE 25000 TCK ENDSTATE IDLE;
    jtag_select_state(RUN_TEST_IDLE);
    jtag_toggle_clk(1000000 / period);

    uint32_t *buf;
    int32_t ret;
    bool last_chunk;
    while ((ret = cb(&buf, &last_chunk)) > 0) {
        assert(ret <= 512);
        jtag_shift_dr(buf, NULL, ret * 8, last_chunk ? EXIT1_DR : SHIFT_DR);
        if (last_chunk) {
            break;
        }
    }
    if (ret < 0) {
        return false;
    }
    // SIR 10 TDI (004);
    cmd = 0x004;
    jtag_shift_ir(&cmd, IRLENGTH, PAUSE_IR);
    // RUNTEST 125 TCK;
    jtag_select_state(RUN_TEST_IDLE);
    jtag_toggle_clk(5000 / period);
    // SDR 732 TDI (000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000) TDO (00000000000000000000000000000000000000000000000000000
    // 0000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000) MASK (000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000
    // 000000000000000000000000000000000000000000000000000000000000000000);
    uint32_t tx[23] = {}, rx[23] = {};
    jtag_shift_dr(tx, rx, 732, RUN_TEST_IDLE);
    if ((rx[14] ^ 0x40000000u) & 0x40000000u) {
        return false;
    }
    // SIR 10 TDI (003);
    cmd = 0x003;
    jtag_shift_ir(&cmd, IRLENGTH, PAUSE_IR);
    // RUNTEST 102400 TCK;
    jtag_select_state(RUN_TEST_IDLE);
    jtag_toggle_clk(4096000 / period);
    // RUNTEST 512 TCK;
    jtag_select_state(RUN_TEST_IDLE);
    jtag_toggle_clk(20480 / period);
    // SIR 10 TDI (3FF);
    cmd = 0x3FF;
    jtag_shift_ir(&cmd, IRLENGTH, PAUSE_IR);
    // RUNTEST IDLE 25000 TCK;
    jtag_select_state(RUN_TEST_IDLE);
    jtag_toggle_clk(1000000 / period);
    // STATE IDLE;
    jtag_select_state(RUN_TEST_IDLE);
    return true;
}

uint32_t alt_flash_exec(uint8_t cmd, uint8_t nbytes)
{
    assert(nbytes <= 4);
    uint32_t rx = 0;
    uint32_t cmd_buf = reverse_byte(cmd);

    shift_vir(0);

    if (nbytes > 0) {
        shift_vdr(&cmd_buf, NULL, 9, SHIFT_DR);
        jtag_shift_dr(NULL, &rx, nbytes * 8, UPDATE_DR);
    } else {
        shift_vdr(&cmd_buf, NULL, 8, UPDATE_DR);
    }

    if (nbytes == 1) {
        rx = reverse_byte(rx);
    } else if (nbytes == 2) {
        rx = (reverse_byte(rx) << 8)
            | reverse_byte(rx >> 8);
    } else if (nbytes == 3) {
        rx = (reverse_byte(rx) << 16)
            | (reverse_byte(rx >> 8) << 8)
            | reverse_byte(rx >> 16);
    } else if (nbytes == 4) {
        rx = (reverse_byte(rx) << 24)
            | (reverse_byte(rx >> 8) << 16)
            | (reverse_byte(rx >> 16) << 8)
            | reverse_byte(rx >> 24);
    }
    return rx;
}

bool alt_flash_wait(uint8_t cmd, uint8_t want, uint8_t mask, uint32_t timeout_ms)
{
    uint32_t rx;
    uint8_t reg;
    uint32_t cmd_buf = reverse_byte(cmd);
    absolute_time_t timeout = make_timeout_time_ms(timeout_ms);
    bool ret = true;

    shift_vir(0);
    shift_vdr(&cmd_buf, NULL, 9, SHIFT_DR);

    do {
        jtag_shift_dr(NULL, &rx, 8, SHIFT_DR);
        reg = reverse_byte(rx);
        if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            ret = false;
            goto out;
        }
    } while ((reg & mask) != want);
out:
    jtag_select_state(UPDATE_DR);
    return ret;
}

void alt_flash_rw(uint8_t cmd, uint32_t addr, const uint32_t *tx, uint32_t *rx, uint32_t nbytes)
{
    assert(tx == NULL || rx == NULL);

    uint32_t cmd_buf = reverse_byte(cmd);
    uint32_t addr_buf = (reverse_byte(addr) << 16)
        | (reverse_byte(addr >> 8) << 8)
        | reverse_byte(addr >> 16);

    shift_vir(0);
    shift_vdr(&cmd_buf, NULL, 8, SHIFT_DR);
    jtag_shift_dr(&addr_buf, NULL, rx == NULL ? 24 : 25, (rx == NULL && tx == NULL) ? UPDATE_DR : SHIFT_DR);

    if (tx != NULL) {
        jtag_shift_dr(tx, NULL, nbytes * 8, UPDATE_DR);
    } else if (rx != NULL) {
        jtag_shift_dr(NULL, rx, nbytes * 8, UPDATE_DR);
    }
}

static void shift_vir(bool reg)
{
    uint32_t cmd = 0x0E;
    uint32_t vir = 0x20 | reg; // IR address can be found in map.rpt file

    jtag_select_state(RUN_TEST_IDLE);

    jtag_shift_ir(&cmd, IRLENGTH, UPDATE_IR);
    jtag_shift_dr(&vir, NULL, 7, UPDATE_DR);
}

static void shift_vdr(const uint32_t *tx, uint32_t *rx, uint32_t len, enum tap_state end_state)
{
    uint32_t cmd = 0x0C;
    jtag_shift_ir(&cmd, IRLENGTH, UPDATE_IR);
    jtag_shift_dr(tx, rx, len, end_state);
}
