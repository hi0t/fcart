#pragma once

#include <stdint.h>

// Process a 512-byte block written to the disk
void uf2_write_block(const uint8_t *data);
bool uf2_is_block(const uint8_t *data);

void uf2_on_write_complete();

// Callback evoked when flashing is complete
void bootloader_flash_success_cb();
