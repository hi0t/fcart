#include "gpio.h"

#define SCAN_PERIOD_MS 7
#define SET 0xFFFFU
#define RESET 0x0000U
#define PRESS 0x000FU
#define MASK 0xF00FU

static uint16_t sd_history = RESET;
static uint32_t led_blink_interval = 0;

static void (*button_cb)();
static void (*sd_cb)(bool);

void set_blink_interval(uint32_t interval_ms)
{
    led_blink_interval = interval_ms;
}

void gpio_poll()
{
    static uint32_t last_time = RESET;
    static uint32_t last_blink_time = 0;
    static uint16_t btn_history = RESET;
    static bool btn_pressed = false;
    static bool sd_present = false;
    uint32_t now = HAL_GetTick();

    if (led_blink_interval > 0 && (now - last_blink_time >= led_blink_interval)) {
        last_blink_time = now;
        HAL_GPIO_TogglePin(GPIO_LED_PORT, GPIO_LED_PIN);
    }

    if (btn_history == SET) {
        btn_pressed = true;
    } else if (btn_history == RESET) {
        btn_pressed = false;
    }

    if (now - last_time > SCAN_PERIOD_MS) {
        last_time = now;

        btn_history = (btn_history << 1) | (HAL_GPIO_ReadPin(GPIO_BTN_PORT, GPIO_BTN_PIN) == GPIO_PIN_SET);
        sd_history = (sd_history << 1) | is_sd_present();

        if (button_cb != NULL && !btn_pressed && (btn_history & MASK) == PRESS) {
            button_cb();
        }

        if (!sd_present && sd_history == SET) {
            sd_present = true;
            if (sd_cb != NULL) {
                sd_cb(true);
            }
        } else if (sd_present && sd_history == RESET) {
            sd_present = false;
            if (sd_cb != NULL) {
                sd_cb(false);
            }
        }
    }
}

void set_button_callback(void (*cb)())
{
    button_cb = cb;
}

void set_sd_callback(void (*cb)(bool))
{
    sd_cb = cb;
}

bool is_sd_present()
{
    return HAL_GPIO_ReadPin(GPIO_SD_CD_PORT, GPIO_SD_CD_PIN) == GPIO_PIN_RESET;
}
