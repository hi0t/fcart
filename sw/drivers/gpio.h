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
 * @brief Sets the interval for the LED to blink.
 *
 * @param interval_ms Blink interval in milliseconds. Set to 0 to disable blinking.
 */
void set_blink_interval(uint32_t interval_ms);

/**
 * @brief Periodically polls GPIO pins to detect button presses and SD card presence.
 *
 * This function should be called regularly (e.g., from a timer interrupt or main loop).
 * It implements debouncing for a button and for SD card detection using counters.
 */
void gpio_poll();

/**
 * @brief Callback function for button press events.
 *
 * This function is called when the button is pressed.
 * It is defined as weak and can be overridden by the user.
 */
void button_callback(void);

/**
 * @brief Callback function for SD card presence events.
 *
 * This function is called when the SD card presence changes.
 * It is defined as weak and can be overridden by the user.
 *
 * @param present true if the SD card is present, false otherwise.
 */
void sd_callback(bool present);

/**
 * @brief Checks if the SD card is currently present.
 *
 * This function returns true if the SD card is detected as present, false otherwise.
 *
 * @return true if the SD card is present, false otherwise
 */
bool is_sd_present();

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
