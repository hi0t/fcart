#pragma once

#include <stdint.h>

int qspi_send(uint8_t cmd, const uint8_t *data, uint32_t size);
