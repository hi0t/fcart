#pragma once

#include <stdint.h>

int fpga_cfg_begin();
int fpga_cfg_put(uint8_t *data, uint32_t len);
int fpga_cfg_end();
