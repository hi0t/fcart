#include "gfx.h"
#include "font8x8.h"
#include "fpga_api.h"
#include <stdlib.h>
#include <string.h>

#define SCREEN_WIDTH 256
#define SCREEN_HEIGHT 240
#define BPP 2 // Bits per pixel
#define FB_SIZE (SCREEN_WIDTH * SCREEN_HEIGHT / 8U * BPP)

static uint8_t framebuffer[FB_SIZE];
static uint8_t curr_buffer;
static bool fb_reader(uint8_t *data, uint32_t size, void *arg);

void gfx_pixel(uint16_t x, uint16_t y, uint8_t color)
{
    if (x >= SCREEN_WIDTH || y >= SCREEN_HEIGHT) {
        return;
    }
    uint32_t tile_idx = (y / 8 * 32) + (x / 8);
    uint32_t fb_idx = (tile_idx * 16) + (y % 8); // Each tile is 16 bytes
    uint8_t bitmask = 128U >> (x % 8);
    framebuffer[fb_idx] &= ~bitmask; // Clear the bits for this pixel
    if (color & 0x01) {
        framebuffer[fb_idx] |= bitmask;
    }

    fb_idx += 8; // Move to the second byte for 2bpp
    framebuffer[fb_idx] &= ~bitmask;
    if (color & 0x02) {
        framebuffer[fb_idx] |= bitmask;
    }
}

void gfx_text(uint16_t x, uint16_t y, const char *str, uint8_t color)
{
    while (*str) {
        char c = *str++;
        if (c < 32 || c > 127) {
            c = '?'; // Replace unsupported characters
        }
        const uint8_t *char_bitmap = font8x8[c - 32];
        for (int row = 0; row < 8; row++) {
            for (int col = 0; col < 8; col++) {
                if (char_bitmap[row] & 1 << col) {
                    gfx_pixel(x + col, y + row, color);
                }
            }
        }
        x += 8; // Move to the next character position
    }
}

void gfx_line(uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1, uint8_t color)
{
    int dx = abs(x1 - x0);
    int sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0);
    int sy = y0 < y1 ? 1 : -1;
    int err = dx + dy; // error value e_xy

    while (true) {
        gfx_pixel(x0, y0, color);
        if (x0 == x1 && y0 == y1)
            break;
        int err2 = 2 * err;
        if (err2 >= dy) { // e_xy + e_x > 0
            err += dy;
            x0 += sx;
        }
        if (err2 <= dx) { // e_xy + e_y < 0
            err += dx;
            y0 += sy;
        }
    }
}

void gfx_fill_rect(uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint8_t color)
{
    for (uint16_t i = 0; i < h; i++) {
        for (uint16_t j = 0; j < w; j++) {
            gfx_pixel(x + j, y + i, color);
        }
    }
}

void gfx_clear()
{
    memset(framebuffer, 0, sizeof(framebuffer));
}

void gfx_refresh()
{
    uint32_t offset = 0;
    uint32_t addr = 0;

    curr_buffer = !curr_buffer;
    if (curr_buffer) {
        addr = 1U << 14;
    }
    fpga_api_write_mem(addr, FB_SIZE, fb_reader, &offset);

    uint32_t args = curr_buffer;
    fpga_api_write_reg(FPGA_REG_LOADER, args);
}

static bool fb_reader(uint8_t *data, uint32_t size, void *arg)
{
    uint32_t *off = arg;
    if (*off + size > FB_SIZE) {
        return false;
    }
    memcpy(data, framebuffer + *off, size);
    *off += size;
    return true;
}
