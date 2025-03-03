#pragma once

#include <stm32f4xx_hal.h>

static inline void led_toggle()
{
    HAL_GPIO_TogglePin(GPIO_LED_PORT, GPIO_LED_PIN);
}
