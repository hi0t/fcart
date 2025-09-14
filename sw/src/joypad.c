#include "joypad.h"
#include "fpga_api.h"
#include <gpio.h>
#include <soc.h>

#define SCAN_PERIOD_MS 20
static bool reading;
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
    if (irq_called()) {
        if (!reading) {
            reading = true;
            last_time = 0;
            last_buttons = 0;
        }
    }

    if (reading) {
        uint32_t now = uptime_ms();
        if (now - last_time < SCAN_PERIOD_MS) {
            return;
        }
        last_time = now;

        uint32_t args;
        fpga_api_read_reg(FPGA_REG_LOADER, &args);
        uint8_t buttons = args & 0xFF;

        if (buttons == 0) {
            reading = false;
            return;
        }

        uint8_t pressed_buttons = (last_buttons ^ buttons) & buttons;
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

        if (pressed_cb != NULL) {
            if (pressed_buttons != 0) {
                pressed_cb(pressed_buttons);
            }
        }
        last_buttons = buttons;
    }
}
