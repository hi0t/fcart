#pragma once

#include <pico/types.h>

extern const uint8_t bit_reverse_table[256];

static inline uint8_t reverse_byte(uint8_t num)
{
    return bit_reverse_table[num];
}
