#pragma once

#include <stdint.h>

uint32_t virt_fat_get_block_count();
uint16_t virt_fat_get_block_size();

// Read a 512-byte block
void virt_fat_read(uint32_t lba, void *buffer);

// Write a block (used for uf2 flashing)
void virt_fat_write(uint8_t *buffer, uint32_t bufsize);

void virt_fat_flush();
