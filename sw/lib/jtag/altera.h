#pragma once

#include <pico/types.h>

// Gets another buffer with the fpga configuration by 512 bytes
typedef int32_t (*alt_reader_cb)(uint32_t **, bool *last);

void alt_init(uint tck, uint tms, uint tdi, uint tdo);
void alt_deinit();
bool alt_scan();
void alt_reset();
bool alt_program_mem(alt_reader_cb cb);
uint32_t alt_flash_exec(uint8_t cmd, uint8_t nbytes);
bool alt_flash_wait(uint8_t cmd, uint8_t want, uint8_t mask, uint32_t timeout_ms);
void alt_flash_rw(uint8_t cmd, uint32_t addr, const uint32_t *tx, uint32_t *rx, uint32_t nbytes);
