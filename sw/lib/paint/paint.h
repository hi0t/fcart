#pragma once

#include <stdbool.h>
#include <stdint.h>

struct paint_nametable;

void paint_pallete(uint8_t background, uint8_t highlight, uint8_t foreground);
void paint_start(struct paint_nametable *nm);
void paint_text(struct paint_nametable *nm, uint16_t r, uint8_t c, const char *str, bool highlight);
void paint_end(struct paint_nametable *nm);
