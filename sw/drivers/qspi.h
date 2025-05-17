#pragma once

#include <stdint.h>

int qspi_cmd(uint8_t cmd);
int qspi_write(uint8_t cmd, uint32_t address, const uint8_t *data, uint32_t size);
