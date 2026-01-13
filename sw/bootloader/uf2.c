#include "uf2.h"
#include <stm32f4xx_hal.h>
#include <string.h>

#define UF2_MAGIC_START0 0x0A324655UL // "UF2\n"
#define UF2_MAGIC_START1 0x9E5D5157UL // Randomly selected
#define UF2_MAGIC_END 0x0AB16F30UL // Dit-to

#define UF2_FLAG_NOT_MAIN_FLASH 0x00000001
#define UF2_FLAG_FILE_CONTAINER 0x00001000
#define UF2_FLAG_FAMILY_ID_PRESENT 0x00002000
#define UF2_FLAG_MD5_PRESENT 0x00004000

#define STM32F4_FAMILY_ID 0x57755a57

typedef struct {
    uint32_t magicStart0;
    uint32_t magicStart1;
    uint32_t flags;
    uint32_t targetAddr;
    uint32_t payloadSize;
    uint32_t blockNo;
    uint32_t numBlocks;
    uint32_t familyID; // or fileSize
    uint8_t data[476];
    uint32_t magicEnd;
} UF2_Block;

static uint32_t erased_sectors_mask;
static uint8_t first_block_buf[512];
static bool has_buffered_first_block;
static bool transfer_complete;

static uint32_t get_sector(uint32_t address)
{
    if (address < 0x08004000)
        return FLASH_SECTOR_0;
    if (address < 0x08008000)
        return FLASH_SECTOR_1;
    if (address < 0x0800C000)
        return FLASH_SECTOR_2;
    if (address < 0x08010000)
        return FLASH_SECTOR_3;
    if (address < 0x08020000)
        return FLASH_SECTOR_4;
    if (address < 0x08040000)
        return FLASH_SECTOR_5;
    if (address < 0x08060000)
        return FLASH_SECTOR_6;
    if (address < 0x08080000)
        return FLASH_SECTOR_7;
    if (address < 0x080A0000)
        return FLASH_SECTOR_8;
    if (address < 0x080C0000)
        return FLASH_SECTOR_9;
    if (address < 0x080E0000)
        return FLASH_SECTOR_10;
    return FLASH_SECTOR_11;
}

bool flash_program(uint32_t address, const uint8_t *data, uint32_t length)
{
    for (uint32_t i = 0; i < length; i += 4) {
        uint32_t val = *(uint32_t *)(data + i);

        if (HAL_FLASH_Program(FLASH_TYPEPROGRAM_WORD, address + i, val) != HAL_OK) {
            return false;
        }
    }
    return memcmp((void *)address, data, length) == 0;
}

static bool write_uf2_content(UF2_Block *uf2)
{
    uint32_t addr = uf2->targetAddr;
    uint32_t size = uf2->payloadSize;

    // Bootloader protection
    if (addr < APP_ADDRESS) {
        return false;
    }

    HAL_FLASH_Unlock();

    // Auto-erase sector on first write
    // get_sector returns 0..11 for F4.
    uint32_t sector = get_sector(addr);
    if (!((erased_sectors_mask >> sector) & 1)) {
        FLASH_Erase_Sector(sector, FLASH_VOLTAGE_RANGE_3);
        erased_sectors_mask |= (1 << sector);
    }

    // Write Data
    bool ret = flash_program(addr, uf2->data, size);

    HAL_FLASH_Lock();

    return ret;
}

bool uf2_is_block(const uint8_t *data)
{
    UF2_Block *uf2 = (UF2_Block *)data;

    // Validate Magic
    if (uf2->magicStart0 != UF2_MAGIC_START0 || uf2->magicStart1 != UF2_MAGIC_START1 || uf2->magicEnd != UF2_MAGIC_END) {
        return false;
    }

    if ((uf2->flags & UF2_FLAG_FAMILY_ID_PRESENT) && (uf2->familyID != STM32F4_FAMILY_ID)) {
        return false;
    }

    return true;
}

void uf2_write_block(const uint8_t *data)
{
    UF2_Block *uf2 = (UF2_Block *)data;

    if (uf2->blockNo == 0) {
        erased_sectors_mask = 0;
        has_buffered_first_block = false;
        transfer_complete = false;
        // Buffer first block to write it at the end.
        // This ensures that if flashing fails in the middle, the old firmware
        // (or at least its start) might still be somewhat preserved,
        // or effectively marks the image as valid only after all other blocks are written.
        if (uf2->numBlocks > 1) {
            memcpy(first_block_buf, data, 512);
            has_buffered_first_block = true;
            return;
        }
    }

    if ((uf2->flags & UF2_FLAG_FAMILY_ID_PRESENT) && (uf2->familyID != STM32F4_FAMILY_ID)) {
        return;
    }

    if (!write_uf2_content(uf2)) {
        return;
    }

    if (uf2->blockNo == uf2->numBlocks - 1) {
        transfer_complete = true;
    }
}

void uf2_on_write_complete()
{
    if (transfer_complete) {
        if (has_buffered_first_block) {
            write_uf2_content((UF2_Block *)first_block_buf);
        }
        bootloader_flash_success_cb();
        transfer_complete = false;
        has_buffered_first_block = false;
    }
}
