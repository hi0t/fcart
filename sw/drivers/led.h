#pragma once

#include <stm32f4xx_hal.h>

/**
 * @brief Toggles the state of the LED.
 *
 * This function changes the state of the LED from on to off or from off to on.
 */
static inline void led_toggle()
{
    HAL_GPIO_TogglePin(GPIO_LED_PORT, GPIO_LED_PIN);
}
