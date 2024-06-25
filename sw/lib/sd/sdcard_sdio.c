#include "diskio.h"
#include "sdcard.h"
#include "sdcard_priv.h"
#include "sdio.h"
#include "trace.h"
#include <hardware/rtc.h>
#include <pico/stdlib.h>

static struct sdcard {
    bool connected;
    sd_type type;
    uint32_t sectors;
    uint32_t rca;
    uint d0;
} sd;

static sd_err sdio2sd_err(sdio_err err)
{
    switch (err) {
    case SDIO_ERR_OK:
        return SD_ERR_OK;
    case SDIO_ERR_TIMEOUT:
        return SD_ERR_NO_RESPONSE;
    case SDIO_ERR_CRC:
        return SD_ERR_CRC;
    case SDIO_ERR_RESPONSE_CMD:
        return SD_ERR_PARAM;
    case SDIO_ERR_WRITE:
        return SD_ERR_WRITE;
    default:
        return SD_ERR_UNSUPPORTED;
    }
}

static sd_err ensure_connect()
{
    if (sd.connected) {
        return SD_ERR_OK;
    }

    uint32_t reply = 0, ocr;
    sdio_err rc;
    absolute_time_t timeout;

    // Connect to card
    for (int i = 0; i < 10; i++) {
        sdio_cmd_R0(CMD0_GO_IDLE_STATE, 0);
        rc = sdio_cmd_R1(CMD8_SEND_IF_COND, 0x1AA, &reply);
        if (rc == SDIO_ERR_OK && reply == 0x1AA) {
            break;
        }
        sleep_ms(1);
    }
    if (reply != 0x1AA || rc != SDIO_ERR_OK) {
        TRACE("SD not responding: %u", rc);
        return SD_ERR_NO_DEVICE;
    }

    timeout = make_timeout_time_ms(SD_INIT_TIMEOUT_MS);
    // Card initialization
    do {
        if ((rc = sdio_cmd_R1(CMD55_APP_CMD, 0, &reply)) != SDIO_ERR_OK
            || (rc = sdio_cmd_R3(ACMD41_SD_SEND_OP_COND, 0xD0040000, &ocr)) != SDIO_ERR_OK) // 3.0V voltage
        {
            TRACE("SD failed to init: %u", rc);
            return sdio2sd_err(rc);
        }
        if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            TRACE("SD initialization timeout");
            return SD_ERR_NO_INIT;
        }
    } while (!(ocr & (1 << 31)));
    sd.type = ocr & (1 << 30) ? SD_CARD_TYPE_SDHC : SD_CARD_TYPE_SD2;

    CID cid;
    if ((rc = sdio_cmd_R2(CMD2_ALL_SEND_CID, 0, cid)) != SDIO_ERR_OK) {
        TRACE("SD failed to read CID: %u", rc);
        return sdio2sd_err(rc);
    }

    // Relative card address
    if ((rc = sdio_cmd_R1(CMD3_SEND_RELATIVE_ADDR, 0, &sd.rca)) != SDIO_ERR_OK) {
        TRACE("SD failed to get RCA: %u", rc);
        return sdio2sd_err(rc);
    }

    CSD csd;
    if ((rc = sdio_cmd_R2(CMD9_SEND_CSD, sd.rca, csd)) != SDIO_ERR_OK) {
        TRACE("SD failed to read CSD: %u", rc);
        return sdio2sd_err(rc);
    }
    sd.sectors = sd_sectors(csd);
    if (sd.sectors == 0) {
        TRACE("SD unsupported CSD");
        return SD_ERR_UNSUPPORTED;
    }

    // Select card
    if ((rc = sdio_cmd_R1(CMD7_SELECT_CARD, sd.rca, &reply)) != SDIO_ERR_OK) {
        TRACE("SD failed to select card: %u", rc);
        return sdio2sd_err(rc);
    }

    // Set 4-bit bus mode
    if ((rc = sdio_cmd_R1(CMD55_APP_CMD, sd.rca, &reply)) != SDIO_ERR_OK
        || (rc = sdio_cmd_R1(ACMD6_SET_BUS_WIDTH, 2, &reply)) != SDIO_ERR_OK) {
        TRACE("SD failed to set bus width: %u", rc);
        return sdio2sd_err(rc);
    }

    // Set operating frequency 31.25 Mhz
    sdio_set_clkdiv(2);
    sd.connected = true;
    return SD_ERR_OK;
}

static sdio_err stop_transfer(uint32_t timeout_ms)
{
    uint32_t reply;
    sdio_err rc = sdio_cmd_R1(CMD12_STOP_TRANSMISSION, 0, &reply);
    if (rc != SDIO_ERR_OK) {
        return rc;
    }
    absolute_time_t timeout = make_timeout_time_ms(timeout_ms);
    while (!gpio_get(sd.d0)) {
        if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            TRACE("SD timeout while transmission is stopped");
            return SDIO_ERR_TIMEOUT;
        }
    }
    return SDIO_ERR_OK;
}

static sd_err read_blocks(uint8_t *buf, uint32_t sectorNum, uint32_t sectorCnt)
{
    TRACE("SD reading sector. Num: %lu, Cnt: %lu", sectorNum, sectorCnt);
    if (sectorNum + sectorCnt > sd.sectors) {
        TRACE("SD invalid sector");
        return SD_ERR_PARAM;
    }
    if (!sd.connected) {
        TRACE("SD device is not initialized");
        return SD_ERR_NO_INIT;
    }

    uint32_t addr = sd.type == SD_CARD_TYPE_SDHC ? sectorNum : sectorNum * BLOCK_SIZE;
    uint32_t reply;
    sdio_err rc = SD_ERR_OK;

    if ((rc = sdio_cmd_R1(CMD16_SET_BLOCKLEN, BLOCK_SIZE, &reply)) != SDIO_ERR_OK) {
        TRACE("SD failed to set block size: %u", rc);
        return sdio2sd_err(rc);
    }
    sdio_start_recv(buf, BLOCK_SIZE, sectorCnt);

    if (sectorCnt > 1) {
        rc = sdio_cmd_R1(CMD18_READ_MULTIPLE_BLOCK, addr, &reply);
    } else {
        rc = sdio_cmd_R1(CMD17_READ_SINGLE_BLOCK, addr, &reply);
    }
    if (rc != SDIO_ERR_OK) {
        TRACE("SD failed to start reception: %u", rc);
        return sdio2sd_err(rc);
    }

    absolute_time_t timeout = make_timeout_time_ms(SD_READ_TIMEOUT_MS);
    uint32_t last_blocks_done = -1;
    uint32_t blocks_done = 0;
    do {
        rc = sdio_poll_recv(&blocks_done);
        if (last_blocks_done != blocks_done) {
            timeout = make_timeout_time_ms(SD_READ_TIMEOUT_MS);
            last_blocks_done = blocks_done;
        } else if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            sdio_stop_transfer();
            TRACE("SD block read timeout");
            return SD_ERR_NO_RESPONSE;
        }
    } while (rc == SDIO_ERR_OK);
    if (rc == SDIO_ERR_EOF) {
        rc = SDIO_ERR_OK;
    }

    if (rc == SDIO_ERR_OK && sectorCnt > 1) {
        rc = stop_transfer(SD_READ_TIMEOUT_MS);
    }
    return sdio2sd_err(rc);
}

static sd_err write_blocks(const uint8_t *buf, uint32_t sectorNum, uint32_t sectorCnt)
{
    TRACE("SD writung sector. Num: %lu, Cnt: %lu", sectorNum, sectorCnt);
    if (sectorNum + sectorCnt > sd.sectors) {
        TRACE("SD invalid sector");
        return SD_ERR_PARAM;
    }
    if (!sd.connected) {
        TRACE("SD device is not initialized");
        return SD_ERR_NO_INIT;
    }

    uint32_t addr = sd.type == SD_CARD_TYPE_SDHC ? sectorNum : sectorNum * BLOCK_SIZE;
    uint32_t reply;
    sdio_err rc = SDIO_ERR_OK;

    if ((rc = sdio_cmd_R1(CMD16_SET_BLOCKLEN, BLOCK_SIZE, &reply)) != SDIO_ERR_OK) {
        TRACE("SD failed to set block size: %u", rc);
        return sdio2sd_err(rc);
    }

    if (sectorCnt == 1) {
        rc = sdio_cmd_R1(CMD24_WRITE_BLOCK, addr, &reply);
    } else {
        rc = sdio_cmd_R1(CMD55_APP_CMD, sd.rca, &reply)
            || sdio_cmd_R1(ACMD23_SET_WR_BLK_ERASE_COUNT, sectorCnt, &reply)
            || sdio_cmd_R1(CMD25_WRITE_MULTIPLE_BLOCK, addr, &reply);
    }
    if (rc != SDIO_ERR_OK) {
        TRACE("SD failed to start transmission: %u", rc);
        return sdio2sd_err(rc);
    }
    sdio_start_send(buf, BLOCK_SIZE, sectorCnt);
    absolute_time_t timeout = make_timeout_time_ms(SD_WRITE_TIMEOUT_MS);
    uint32_t last_blocks_done = -1;
    uint32_t blocks_done = 0;
    do {
        rc = sdio_poll_send(&blocks_done);
        if (last_blocks_done != blocks_done) {
            timeout = make_timeout_time_ms(SD_WRITE_TIMEOUT_MS);
            last_blocks_done = blocks_done;
        } else if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            sdio_stop_transfer();
            TRACE("SD block write timeout");
            return SD_ERR_NO_RESPONSE;
        }
    } while (rc == SDIO_ERR_OK);
    if (rc == SDIO_ERR_EOF) {
        rc = SDIO_ERR_OK;
    }

    if (rc == SDIO_ERR_OK && sectorCnt > 1) {
        rc = stop_transfer(SD_WRITE_TIMEOUT_MS);
    }
    return sdio2sd_err(rc);
}

DSTATUS disk_initialize(BYTE pdrv)
{
    sd_err rc = ensure_connect();
    return sd_err2ff(rc);
}

DSTATUS disk_status(BYTE pdrv)
{
    return sd.connected ? 0 : STA_NOINIT;
}

DRESULT disk_read(BYTE pdrv, BYTE *buff, LBA_t sector, UINT count)
{
    sd_err rc = read_blocks(buff, sector, count);
    return sd_err2ff(rc);
}

DRESULT disk_write(BYTE pdrv, const BYTE *buff, LBA_t sector, UINT count)
{
    sd_err rc = write_blocks(buff, sector, count);
    return sd_err2ff(rc);
}

DRESULT disk_ioctl(BYTE pdrv, BYTE cmd, void *buff)
{
    switch (cmd) {
    case GET_SECTOR_COUNT: {
        if (sd.sectors == 0) {
            return RES_ERROR;
        }
        *(LBA_t *)buff = sd.sectors;
        return RES_OK;
    }
    case GET_BLOCK_SIZE: {
        *(DWORD *)buff = 1;
        return RES_OK;
    }
    case CTRL_SYNC:
        return RES_OK;
    default:
        return RES_PARERR;
    }
}

void sdcard_init(uint sck, uint cmd, uint d0)
{
    rtc_init();
    sd.d0 = d0;
    sdio_init(sck, cmd, d0, SD_CMD_TIMEOUT_MS);
    ensure_connect();
}
