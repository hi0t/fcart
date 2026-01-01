#pragma once

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
void gpio_poll();

/**
 * @brief Sets the callback function for button press events.
 *
 * This function sets a callback function that will be called when the button is pressed.
 *
 * @param cb The callback function to set.
 */
void set_button_callback(void (*cb)());

/**
 * @brief Sets the callback function for SD card presence events.
 *
 * This function sets a callback function that will be called when the SD card presence changes.
 *
 * @param cb The callback function to set, which takes a boolean indicating SD card presence.
 */
void set_sd_callback(void (*cb)(bool));

/**
 * @brief Checks if the SD card is currently present.
 *
 * This function returns true if the SD card is detected as present, false otherwise.
 *
 * @return true if the SD card is present, false otherwise
 */
bool sd_is_present();

/**
 * @brief Checks if an interrupt has been called.
 *
 * This function returns true if an interrupt has occurred since the last call to this function.
 * It is used to determine if the main loop needs to handle any events.
 *
 * @return true if an interrupt has occurred, false otherwise
 */
static inline bool irq_called()
{
    return HAL_GPIO_ReadPin(GPIO_IRQ_PORT, GPIO_IRQ_PIN) == GPIO_PIN_SET;
}
