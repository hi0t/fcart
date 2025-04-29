#pragma once

#include <stdint.h>

void spi_begin();
void spi_end();
int spi_send(const uint8_t *data, uint16_t size);
