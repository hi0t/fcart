#pragma once

#include <pico/types.h>

typedef enum {
    SDIO_ERR_OK = 0,
    SDIO_ERR_TIMEOUT = -1,
    SDIO_ERR_CRC = -2,
    SDIO_ERR_RESPONSE_CMD = -3,
    SDIO_ERR_EOF = -4,
    SDIO_ERR_WRITE = -5,
} sdio_err;

void sdio_init(uint sck, uint cmd, uint d0, uint32_t cmd_timeout_ms);
void sdio_set_clkdiv(uint16_t div);

sdio_err sdio_cmd_R0(uint8_t cmd, uint32_t arg);
sdio_err sdio_cmd_R1(uint8_t cmd, uint32_t arg, uint32_t *resp);
sdio_err sdio_cmd_R2(uint8_t cmd, uint32_t arg, uint8_t *resp);
sdio_err sdio_cmd_R3(uint8_t cmd, uint32_t arg, uint32_t *resp);

void sdio_start_recv(uint8_t *buf, uint32_t block_size, uint32_t nblocks);
sdio_err sdio_poll_recv(uint32_t *blocks_complete);

void sdio_stop_transfer();
void sdio_start_send(const uint8_t *buf, uint32_t block_size, uint32_t nblocks);
sdio_err sdio_poll_send(uint32_t *blocks_complete);
