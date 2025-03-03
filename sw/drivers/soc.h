#pragma once

#include <stdint.h>

/**
 * @brief Initializes the hardware.
 *
 * This function performs the necessary hardware initialization
 * required for the system to operate correctly. It should be
 * called at the beginning of the program before any other hardware
 * related functions are used.
 */
void hw_init();

/**
 * @brief Delays the execution for a specified number of milliseconds.
 *
 * This function introduces a delay in the program execution for the specified
 * amount of time in milliseconds. It is typically used to create timed delays
 * in the execution flow.
 *
 * @param ms The number of milliseconds to delay.
 */
void delay_ms(uint32_t ms);

/**
 * @brief Returns the system uptime in milliseconds.
 *
 * This function returns the number of milliseconds since the system
 * was started or since the last reset.
 *
 * @return The system uptime in milliseconds.
 */
uint32_t uptime_ms();
