#include "virt_fat.h"
#include "qspi.h"
#include "soc.h"
#include "uf2.h"
#include <stdio.h>
#include <string.h>

// Disk: ~32MB FAT16 (65536 sectors * 512 bytes)
#define DISK_BLOCK_SIZE 512
#define DISK_BLOCK_COUNT 65536

// BPB Constants
#define FAT_SECTOR_SIZE 512
#define SECTORS_PER_CLUS 1
#define RESERVED_SECTORS 1
#define NUMBER_OF_FATS 2
#define ROOT_ENTRIES 512

// Root Dir: 32 sectors
#define ROOT_DIR_SECTORS ((ROOT_ENTRIES * 32 + (FAT_SECTOR_SIZE - 1)) / FAT_SECTOR_SIZE)

// FAT Size: 256 sectors (covers 65k clusters)
#define FAT_SIZE_SECTORS 256

// Layout Offsets (LBA)
#define LBA_BOOT_SECTOR 0
#define LBA_FAT1 (LBA_BOOT_SECTOR + RESERVED_SECTORS)
#define LBA_FAT2 (LBA_FAT1 + FAT_SIZE_SECTORS)
#define LBA_ROOT_DIR (LBA_FAT2 + FAT_SIZE_SECTORS)
#define LBA_DATA_START (LBA_ROOT_DIR + ROOT_DIR_SECTORS)

// File Content
const char readme_content[] = "fcart bootloader\r\n"
                              "================\r\n"
                              "\r\n"
                              "This drive allows you to update the firmware.\r\n"
                              "Drag and drop a compatible .uf2 file here.\r\n";

#define README_SIZE (sizeof(readme_content) - 1)
#define README_CLUSTER 2 // First available cluster
#define VERSION_CLUSTER 3

static char version_content[128];
static uint32_t version_len = 0;

static void prepare_version_file()
{
    if (version_len > 0)
        return;

    uint8_t app_maj, app_min;

    int pos = snprintf(version_content, sizeof(version_content),
        "fcart info\r\n"
        "==========\r\n"
        "\r\n");

    if (get_sw_version(BOOTLOADER_ADDRESS, &app_maj, &app_min)) {
        pos += snprintf(version_content + pos, sizeof(version_content) - pos,
            "Bootloader:   %d.%d\r\n", app_maj, app_min);
    } else {
        pos += snprintf(version_content + pos, sizeof(version_content) - pos,
            "Bootloader:   not found\r\n");
    }

    if (get_sw_version(APP_ADDRESS, &app_maj, &app_min)) {
        pos += snprintf(version_content + pos, sizeof(version_content) - pos,
            "Firmware:     %d.%d\r\n", app_maj, app_min);
    } else {
        pos += snprintf(version_content + pos, sizeof(version_content) - pos,
            "Firmware:     not found\r\n");
    }

    uint8_t fpga_ver_buf[4];
    if (qspi_read(0x02, 2, fpga_ver_buf, 4) == 0) {
        pos += snprintf(version_content + pos, sizeof(version_content) - pos,
            "FPGA:         %d.%d\r\n", fpga_ver_buf[1], fpga_ver_buf[0]);
    } else {
        pos += snprintf(version_content + pos, sizeof(version_content) - pos,
            "FPGA:         read error\r\n");
    }

    version_len = pos;
}

uint32_t virt_fat_get_block_count()
{
    return DISK_BLOCK_COUNT;
}

uint16_t virt_fat_get_block_size()
{
    return DISK_BLOCK_SIZE;
}

static void write_u16(uint8_t *buf, uint16_t val)
{
    buf[0] = val & 0xFF;
    buf[1] = (val >> 8) & 0xFF;
}

static void write_u32(uint8_t *buf, uint32_t val)
{
    buf[0] = val & 0xFF;
    buf[1] = (val >> 8) & 0xFF;
    buf[2] = (val >> 16) & 0xFF;
    buf[3] = (val >> 24) & 0xFF;
}

void virt_fat_read(uint32_t lba, void *buffer)
{
    uint8_t *buf = (uint8_t *)buffer;
    memset(buf, 0, DISK_BLOCK_SIZE);

    if (lba == LBA_BOOT_SECTOR) {
        // --- Boot Sector & BPB ---
        buf[0] = 0xEB;
        buf[1] = 0x3C;
        buf[2] = 0x90; // JMP opcode
        memcpy(&buf[3], "MSDOS5.0", 8); // OEM Name

        // BPB
        write_u16(&buf[11], FAT_SECTOR_SIZE); // BytesPerSec
        buf[13] = SECTORS_PER_CLUS; // SecPerClus
        write_u16(&buf[14], RESERVED_SECTORS); // RsvdSecCnt
        buf[16] = NUMBER_OF_FATS; // NumFATs
        write_u16(&buf[17], ROOT_ENTRIES); // RootEntCnt
        write_u16(&buf[19], 0); // TotSec16 (0 for > 65k)
        buf[21] = 0xF8; // Media (Fixed disk)
        write_u16(&buf[22], FAT_SIZE_SECTORS); // FATSz16
        write_u16(&buf[24], 32); // SecPerTrk
        write_u16(&buf[26], 64); // NumHeads
        write_u32(&buf[28], 0); // HiddSec
        write_u32(&buf[32], DISK_BLOCK_COUNT); // TotSec32

        // FAT16 Extended
        buf[36] = 0x80; // Drive Number
        buf[38] = 0x29; // ExtBootSig
        write_u32(&buf[39], 0x12345678); // VolumeID
        memcpy(&buf[43], "FCART BOOT ", 11); // VolumeLabel
        memcpy(&buf[54], "FAT16   ", 8); // FileSystemType

        buf[510] = 0x55;
        buf[511] = 0xAA; // Signature
    } else if ((lba >= LBA_FAT1 && lba < LBA_FAT1 + FAT_SIZE_SECTORS) || (lba >= LBA_FAT2 && lba < LBA_FAT2 + FAT_SIZE_SECTORS)) {
        // --- FAT Table ---
        uint32_t fat_offset_sectors;
        if (lba >= LBA_FAT2) {
            fat_offset_sectors = lba - LBA_FAT2;
        } else {
            fat_offset_sectors = lba - LBA_FAT1;
        }

        uint16_t *fat = (uint16_t *)buf;

        // Only the first sector of the FAT has entries we care about
        if (fat_offset_sectors == 0) {
            fat[0] = 0xFFF8; // Media Driver
            fat[1] = 0xFFFF; // End of chain marker
            fat[2] = 0xFFFF; // Cluster 2 (README.TXT) is the last cluster
            fat[3] = 0xFFFF; // Cluster 3 (VERSION.TXT) is the last cluster
        }
    } else if (lba >= LBA_ROOT_DIR && lba < LBA_DATA_START) {
        // --- Root Directory ---
        uint32_t root_sector_idx = lba - LBA_ROOT_DIR;

        // Only put entries in the first sector of root dir
        if (root_sector_idx == 0) {
            // Volume Label Entry
            memcpy(&buf[0], "FCART BOOT ", 11);
            buf[11] = 0x08; // ATTR_VOLUME_ID

            // README.TXT Entry (32 bytes per entry)
            // Offset 32
            uint8_t *entry = &buf[32];
            memcpy(entry, "README  TXT", 11);
            entry[11] = 0x01; // ATTR_READ_ONLY

            // Create time/date (optional, leave 0)

            write_u16(&entry[26], README_CLUSTER); // FirstClusterLow
            write_u32(&entry[28], README_SIZE); // FileSize

            // VERSION.TXT Entry
            // Offset 64
            entry = &buf[64];
            memcpy(entry, "VERSION TXT", 11);
            entry[11] = 0x01; // ATTR_READ_ONLY

            prepare_version_file();
            write_u16(&entry[26], VERSION_CLUSTER); // FirstClusterLow
            write_u32(&entry[28], version_len); // FileSize
        }
    } else if (lba >= LBA_DATA_START) {
        // --- Data Area ---
        uint32_t blk_offset = lba - LBA_DATA_START;
        uint32_t cluster_idx = blk_offset / SECTORS_PER_CLUS + 2;

        if (cluster_idx == README_CLUSTER) {
            // Copy file content
            // Assuming file fits in one sector for simplicity as per requirements
            memcpy(buf, readme_content, README_SIZE);
        } else if (cluster_idx == VERSION_CLUSTER) {
            prepare_version_file();
            memcpy(buf, version_content, version_len);
        }
    }
}

void virt_fat_write(uint8_t *buffer, uint32_t bufsize)
{
    // Split large writes into 512-byte blocks
    for (uint32_t i = 0; i < bufsize; i += 512) {
        if (bufsize - i >= 512) {
            if (uf2_is_block(buffer + i)) {
                uf2_write_block(buffer + i);
            }
        }
    }
}

void virt_fat_flush()
{
    uf2_on_write_complete();
}
