#pragma once

#include <stdbool.h>
#include <stm32f4xx_hal.h>

/**
 * @brief Control the LED state.
 *
 * This function sets the LED on or off based on the provided boolean value.
 *
 * @param on  true to turn the LED on, false to turn it off
 */
static inline void led_on(bool on)
{
    HAL_GPIO_WritePin(GPIO_LED_PORT, GPIO_LED_PIN, on ? GPIO_PIN_SET : GPIO_PIN_RESET);
}

/**
 * @brief Periodically polls GPIO pins to detect button presses and SD card presence.
 *
 * This function should be called regularly (e.g., from a timer interrupt or main loop).
 * It implements debouncing for a button and for SD card detection using counters.
 */
void gpio_pull();

/**
 * @brief Sets the callback function for button press events.
 *
 * This function sets a callback function that will be called when the button is pressed.
 *
 * @param cb The callback function to set.
 */
void set_button_callback(void (*cb)());

/**
 * @brief Checks if an SD card is present.
 *
 * This function detects whether an SD card is currently inserted or present.
 *
 * @return true if the SD card is present, false otherwise.
 */
bool sd_present();
