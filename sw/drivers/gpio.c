#include "gpio.h"

#define SCAN_PERIOD_MS 5
#define SET 0xFFFFU
#define RESET 0x0000U
#define PRESS 0x0FFFU

static void (*button_cb)();
static uint16_t sd_history = 0;

void gpio_pull()
{
    static uint32_t last_time = RESET;
    static uint16_t btn_history = RESET;
    static bool power_up = true;
    uint32_t now = HAL_GetTick();

    if (power_up) {
        power_up = false;
        sd_history = (HAL_GPIO_ReadPin(GPIO_SD_CD_PORT, GPIO_SD_CD_PIN) == GPIO_PIN_RESET) ? SET : RESET;
    }

    if (now - last_time > SCAN_PERIOD_MS) {
        last_time = now;

        btn_history = (btn_history << 1) | (HAL_GPIO_ReadPin(GPIO_BTN_PORT, GPIO_BTN_PIN) == GPIO_PIN_SET);
        sd_history = (sd_history << 1) | (HAL_GPIO_ReadPin(GPIO_SD_CD_PORT, GPIO_SD_CD_PIN) == GPIO_PIN_RESET);

        if (button_cb != NULL && btn_history == PRESS) {
            button_cb();
        }
    }
}

void set_button_callback(void (*cb)())
{
    button_cb = cb;
}

bool sd_present()
{
    return sd_history == SET;
}
