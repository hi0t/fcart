#pragma once

#include <stdint.h>

uint8_t crc7(const uint8_t *buf, uint32_t len);
uint16_t crc16(const uint8_t *buf, uint32_t len);
