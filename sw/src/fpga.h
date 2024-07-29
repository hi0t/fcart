#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef bool (*fpga_reader_cb)(uint16_t *, void *);

void fpga_init();
void fpga_write_prg(uint32_t address, uint32_t size, fpga_reader_cb cb, void *arg);
void fpga_write_chr(uint32_t address, uint32_t size, fpga_reader_cb cb, void *arg);
void fpga_launch();
