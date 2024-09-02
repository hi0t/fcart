#pragma once

#include <pico/types.h>

enum tap_state {
    TEST_LOGIC_RESET = 0,
    RUN_TEST_IDLE = 1,
    SELECT_DR_SCAN = 2,
    CAPTURE_DR = 3,
    SHIFT_DR = 4,
    EXIT1_DR = 5,
    PAUSE_DR = 6,
    EXIT2_DR = 7,
    UPDATE_DR = 8,
    SELECT_IR_SCAN = 9,
    CAPTURE_IR = 10,
    SHIFT_IR = 11,
    EXIT1_IR = 12,
    PAUSE_IR = 13,
    EXIT2_IR = 14,
    UPDATE_IR = 15
};

void jtag_init(uint16_t clkdiv, uint tck, uint tms, uint tdi, uint tdo);
void jtag_deinit();
uint32_t jtag_freq();
void jtag_reset();
void jtag_select_state(enum tap_state next_states);
void jtag_shift_ir(const uint32_t *tdi, uint32_t len, enum tap_state end_state);
void jtag_shift_dr(const uint32_t *tdi, uint32_t *tdo, uint32_t len, enum tap_state end_state);
void jtag_toggle_clk(uint32_t len);
