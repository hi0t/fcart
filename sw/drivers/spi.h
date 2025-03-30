#pragma once

#include <stdint.h>

int spi_transmit_receive(const uint8_t *tx, uint8_t *rx, uint16_t size);
