#pragma once

#include <stdint.h>

int qspi_read(uint8_t cmd, uint32_t address, uint8_t *data, uint32_t size);
int qspi_write(uint8_t cmd, uint32_t address, const uint8_t *data, uint32_t size);
int qspi_write_begin(uint8_t cmd, uint32_t address, const uint8_t *data, uint32_t size);
int qspi_write_end();
