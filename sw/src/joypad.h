#pragma once

#include <stdint.h>

enum {
    BUTTON_RIGHT = 1 << 0,
    BUTTON_LEFT = 1 << 1,
    BUTTON_DOWN = 1 << 2,
    BUTTON_UP = 1 << 3,
    BUTTON_START = 1 << 4,
    BUTTON_SELECT = 1 << 5,
    BUTTON_B = 1 << 6,
    BUTTON_A = 1 << 7,
};

void joypad_set_callback(void (*cb)(uint8_t buttons));
void joypad_can_repeat(uint8_t buttons);
void joypad_poll();
