#pragma once

#include <stdbool.h>
#include <stdint.h>

enum fpga_reg_id {
    FPGA_REG_MAPPER = 0,
    FPGA_REG_LOADER
};

typedef bool (*fpga_api_reader_cb)(uint8_t *, uint32_t, void *);

int fpga_api_write_mem(uint32_t address, uint32_t size, fpga_api_reader_cb cb, void *arg);
int fpga_api_write_reg(enum fpga_reg_id id, uint32_t value);
