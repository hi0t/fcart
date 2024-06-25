#pragma once

#include "diskio.h"
#include <stdint.h>

#define SD_INIT_TIMEOUT_MS 1000
#define SD_READ_TIMEOUT_MS 500
#define SD_WRITE_TIMEOUT_MS 1000
#define SD_CMD_TIMEOUT_MS 100
#define BLOCK_SIZE 512

typedef enum {
    SD_ERR_OK = 0,
    SD_ERR_NO_DEVICE = -1,
    SD_ERR_UNSUPPORTED = -2,
    SD_ERR_NO_RESPONSE = -3,
    SD_ERR_CRC = -4,
    SD_ERR_PARAM = -5,
    SD_ERR_NO_INIT = -6,
    SD_ERR_WRITE = -7,
    SD_ERR_WRITE_PROTECTED = -8
} sd_err;

typedef enum {
    CMD0_GO_IDLE_STATE = 0,
    CMD2_ALL_SEND_CID = 2,
    CMD3_SEND_RELATIVE_ADDR = 3,
    CMD7_SELECT_CARD = 7,
    CMD8_SEND_IF_COND = 8,
    CMD9_SEND_CSD = 9,
    CMD12_STOP_TRANSMISSION = 12,
    CMD13_SEND_STATUS = 13,
    CMD16_SET_BLOCKLEN = 16,
    CMD17_READ_SINGLE_BLOCK = 17,
    CMD18_READ_MULTIPLE_BLOCK = 18,
    CMD24_WRITE_BLOCK = 24,
    CMD25_WRITE_MULTIPLE_BLOCK = 25,
    CMD55_APP_CMD = 55,
    CMD58_READ_OCR = 58,
    CMD59_CRC_ON_OFF = 59,
    // App cmd
    ACMD6_SET_BUS_WIDTH = 6,
    ACMD23_SET_WR_BLK_ERASE_COUNT = 23,
    ACMD41_SD_SEND_OP_COND = 41
} sd_cmd;

typedef enum {
    SD_CARD_TYPE_UNKNOWN = 0,
    SD_CARD_TYPE_SD1,
    SD_CARD_TYPE_SD2,
    SD_CARD_TYPE_SDHC
} sd_type;

typedef uint8_t CSD[16];
typedef uint8_t CID[16];

DSTATUS sd_err2ff(sd_err rc);
uint32_t sd_sectors(CSD csd);
