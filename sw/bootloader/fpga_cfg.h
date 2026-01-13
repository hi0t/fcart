#pragma once

#include <stdint.h>

int fpga_cfg_start();
int fpga_cfg_write(uint8_t *data, uint32_t len);
int fpga_cfg_done();
