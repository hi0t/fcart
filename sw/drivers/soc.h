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
 * @brief Delays the execution for a specified number of microseconds.
 *
 * This function introduces a delay in the program execution for the specified
 * amount of time in microseconds. It is typically used to create timed delays
 * in the execution flow.
 *
 * @param us The number of microseconds to delay.
 */
void delay_us(uint16_t us);

/**
 * @brief Delays the execution for a specified number of milliseconds.
 *
 * This function introduces a delay in the program execution for the specified
 * amount of time in milliseconds. It is typically used to create timed delays
 * in the execution flow.
 *
 * @param ms The number of milliseconds to delay.
 */
void delay_ms(uint16_t ms);

/**
 * @brief Returns the system uptime in milliseconds.
 *
 * This function returns the number of milliseconds since the system
 * was started or since the last reset.
 *
 * @return The system uptime in milliseconds.
 */
uint32_t uptime_ms();

/**
 * @brief Retrieves the software version from the application header in flash.
 *
 * This function checks the magic number in the application header and, if valid,
 * extracts the major and minor version numbers.
 *
 * @param base_addr The base address of the application in flash.
 * @param major Pointer to store the major version number.
 * @param minor Pointer to store the minor version number.
 * @return true if the magic number is valid and version is retrieved, false otherwise.
 */
bool get_sw_version(uint32_t base_addr, uint8_t *major, uint8_t *minor);
