#pragma once

#include <stdint.h>

/**
 * @brief Begins the SPI communication.
 */
void spi_begin();

/**
 * @brief Ends the SPI communication.
 */
void spi_end();

/**
 * @brief Sends data over SPI.
 *
 * @param data Pointer to the data buffer to send.
 * @param size Number of bytes to send.
 * @return int Returns 0 on success, or a negative error code on failure.
 */
int spi_send(const uint8_t *data, uint16_t size);

/**
 * @brief Receives data over SPI.
 *
 * @param data Pointer to the buffer to store received data.
 * @param size Number of bytes to receive.
 * @return int Returns the number of bytes received, or a negative error code on failure.
 */
int spi_recv(uint8_t *data, uint16_t size);
