#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef bool (*fpga_api_reader_cb)(uint8_t *, uint32_t, void *);

int fpga_api_launch();
int fpga_api_load(uint32_t address, uint32_t size, fpga_api_reader_cb cb, void *arg);
