#pragma once

#include <stdbool.h>
#include <stdint.h>

enum fpga_reg_id {
    FPGA_REG_MAPPER = 0,
    FPGA_REG_LAUNCHER = 1,
    FPGA_REG_EVENTS = 1
};

typedef bool (*fpga_api_reader_cb)(uint8_t *, uint32_t, void *);

int fpga_api_write_mem(uint32_t address, uint32_t size, fpga_api_reader_cb cb, void *arg);
int fpga_api_read_reg(enum fpga_reg_id id, uint32_t *value);
int fpga_api_write_reg(enum fpga_reg_id id, uint32_t value);
uint32_t fpga_api_ev_reg();
