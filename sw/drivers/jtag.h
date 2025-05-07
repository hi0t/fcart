#pragma once

#include <stdint.h>

enum jtag_tap_state {
    JTAG_TEST_LOGIC_RESET = 0,
    JTAG_RUN_TEST_IDLE = 1,
    JTAG_SELECT_DR_SCAN = 2,
    JTAG_CAPTURE_DR = 3,
    JTAG_SHIFT_DR = 4,
    JTAG_EXIT1_DR = 5,
    JTAG_PAUSE_DR = 6,
    JTAG_EXIT2_DR = 7,
    JTAG_UPDATE_DR = 8,
    JTAG_SELECT_IR_SCAN = 9,
    JTAG_CAPTURE_IR = 10,
    JTAG_SHIFT_IR = 11,
    JTAG_EXIT1_IR = 12,
    JTAG_PAUSE_IR = 13,
    JTAG_EXIT2_IR = 14,
    JTAG_UPDATE_IR = 15
};

void jtag_resume();
void jtag_suspend();
void jtag_reset();
void jtag_select_state(enum jtag_tap_state next_state);
int jtag_shift_ir(const uint8_t *tdi, uint32_t len, enum jtag_tap_state end_state);
int jtag_shift_dr(const uint8_t *tdi, uint8_t *tdo, uint32_t len, enum jtag_tap_state end_state);
int jtag_toggle_clk(uint32_t len);
