#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef bool (*fpga_api_reader_cb)(uint8_t *, uint32_t, void *);

int fpga_api_launch(uint32_t ppu_off);
int fpga_api_load(uint32_t address, uint32_t size, fpga_api_reader_cb cb, void *arg);
