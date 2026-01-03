#include "joypad.h"
#include "fpga_api.h"
#include <gpio.h>
#include <soc.h>

#define SCAN_PERIOD_MS 20
static uint32_t last_time;
static uint8_t last_buttons;
static uint8_t repeat_buttons;
static uint8_t repeat_delay;

static void (*pressed_cb)(uint8_t buttons);

void joypad_set_callback(void (*cb)(uint8_t buttons))
{
    pressed_cb = cb;
}

void joypad_can_repeat(uint8_t buttons)
{
    repeat_buttons = buttons;
}

void joypad_poll()
{
    uint8_t buttons = fpga_api_ev_reg(false) & 0xFF;
    if (buttons == 0) {
        last_time = 0;
        last_buttons = 0;
        last_buttons = 0;
        repeat_delay = 0;
        return;
    }

    uint32_t now = uptime_ms();
    if (now - last_time < SCAN_PERIOD_MS) {
        return;
    }
    last_time = now;

    uint8_t pressed_buttons = buttons & ~last_buttons; // Edge detection
    if (pressed_buttons & repeat_buttons) {
        repeat_delay = 20; // Initial delay before repeating
    }

    if (repeat_delay > 0) {
        repeat_delay--;
        if (repeat_delay == 0) {
            pressed_buttons |= buttons & repeat_buttons;
            repeat_delay = 5; // Subsequent delay for repeating
        }
    }

    if (pressed_cb != NULL && pressed_buttons != 0) {
        pressed_cb(pressed_buttons);
    }
    last_buttons = buttons;
}
