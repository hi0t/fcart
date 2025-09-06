#pragma once

#include <stdint.h>

void gfx_pixel(uint16_t x, uint16_t y, uint8_t color);
void gfx_text(uint16_t x, uint16_t y, const char *str, uint8_t color);
void gfx_line(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint8_t color);
void gfx_clear();
void gfx_refresh();
