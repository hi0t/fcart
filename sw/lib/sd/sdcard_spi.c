#include "crc.h"
#include "sdcard.h"
#include "sdcard_priv.h"
#include "trace.h"
#include <hardware/rtc.h>
#include <hardware/spi.h>
#include <inttypes.h>
#include <pico/stdlib.h>

#define PACKET_SIZE 6

#define R1_READY_STATE 0
#define R1_IDLE_STATE (1 << 0)
#define R1_ERASE_RESET (1 << 1)
#define R1_ILLEGAL_COMMAND (1 << 2)
#define R1_COM_CRC_ERROR (1 << 3)
#define R1_ERASE_SEQUENCE_ERROR (1 << 4)
#define R1_ADDRESS_ERROR (1 << 5)
#define R1_PARAMETER_ERROR (1 << 6)
#define R1_NO_RESPONSE 0xFF
#define SD_START_BLOCK 0xFE

static struct sdcard {
    spi_inst_t *spi;
    uint cs;
    bool connected;
    sd_type type;
    uint32_t sectors;
} sd;

static void cs_select()
{
    gpio_put(sd.cs, 0);
}

static void cs_deselect()
{
    gpio_put(sd.cs, 1);
}

static uint8_t resp()
{
    uint8_t res;
    spi_read_blocking(sd.spi, 0xFF, &res, 1);
    return res;
}

static bool wait_start_block()
{
    absolute_time_t timeout = make_timeout_time_ms(SD_READ_TIMEOUT_MS);
    while (resp() != SD_START_BLOCK) {
        if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            return false;
        }
    }
    return true;
}

static bool wait_not_busy(uint32_t ms)
{
    absolute_time_t timeout = make_timeout_time_ms(ms);
    while (resp() != 0xFF) {
        if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            return false;
        }
    }
    return true;
}

static uint8_t do_cmd(sd_cmd cmd, uint32_t arg)
{
    TRACE("SD send command %u", cmd);

    if (cmd != CMD12_STOP_TRANSMISSION) {
        if (!wait_not_busy(SD_CMD_TIMEOUT_MS)) {
            TRACE("SD command timeout");
            return R1_NO_RESPONSE;
        }
    }

    uint8_t status;
    uint8_t buf[PACKET_SIZE] = {
        0x40 | (cmd & 0x3F),
        (arg >> 24),
        (arg >> 16),
        (arg >> 8),
        (arg >> 0),
        0
    };
    buf[PACKET_SIZE - 1] = (crc7(buf, PACKET_SIZE - 1) << 1) | 0x01;

    spi_write_blocking(sd.spi, buf, PACKET_SIZE);

    for (int i = 0; i < 0x10; i++) {
        status = resp();
        if (!(status & 0x80)) {
            break;
        }
    }
    return status;
}

static uint8_t do_acmd(sd_cmd cmd, uint32_t arg)
{
    do_cmd(CMD55_APP_CMD, 0);
    return do_cmd(cmd, arg);
}

static sd_err read_single_block(uint8_t *buf, uint32_t size)
{
    if (!wait_start_block()) {
        return SD_ERR_NO_RESPONSE;
    }

    spi_read_blocking(sd.spi, 0xFF, buf, size);

    uint16_t crc;
    crc = (resp() << 8);
    crc |= resp();

    uint16_t checksum = crc16(buf, size);
    if (checksum != crc) {
        TRACE("SD bad crc recevied: 0x%" PRIx16 ". Computed: 0x%" PRIx16, crc, checksum);
        return SD_ERR_CRC;
    }
    return SD_ERR_OK;
}

static sd_err ensure_connect()
{
    if (sd.connected) {
        return SD_ERR_OK;
    }

    TRACE("SD connecting...");

    spi_set_baudrate(sd.spi, 400 * 1000);

    gpio_put(sd.cs, 1);
    // send at least 74 clock cycles
    uint8_t one = 0xFF;
    for (int i = 0; i < 10; i++) {
        spi_write_blocking(sd.spi, &one, 1);
    }

    cs_select();

    sd_err rc = SD_ERR_OK;

    absolute_time_t timeout = make_timeout_time_ms(SD_INIT_TIMEOUT_MS);
    // switch to SPI mode
    while (do_cmd(CMD0_GO_IDLE_STATE, 0) != R1_IDLE_STATE) {
        if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            TRACE("SD couldn't put card to iddle state");
            rc = SD_ERR_NO_DEVICE;
            goto err;
        }
    }

    sd_type type;
    uint8_t status = 0;
    // check SD version and supply voltage
    if ((do_cmd(CMD8_SEND_IF_COND, 0x1AA) & R1_ILLEGAL_COMMAND)) {
        type = SD_CARD_TYPE_SD1;
    } else {
        for (int i = 0; i < 4; i++) {
            status = resp();
        }
        if (status != 0xAA) {
            TRACE("SD card unusable. Status: %u", status);
            rc = SD_ERR_UNSUPPORTED;
            goto err;
        }
        type = SD_CARD_TYPE_SD2;
    }

    // enable crc check
    if ((status = do_cmd(CMD59_CRC_ON_OFF, 1)) != R1_IDLE_STATE) {
        TRACE("SD couldn't enable crc mode. Status: %u", status);
        rc = SD_ERR_UNSUPPORTED;
        goto err;
    }

    uint32_t arg = type == SD_CARD_TYPE_SD2 ? 0X40000000 : 0;
    timeout = make_timeout_time_ms(SD_INIT_TIMEOUT_MS);
    // initialize card
    while (do_acmd(ACMD41_SD_SEND_OP_COND, arg) != R1_READY_STATE) {
        if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            TRACE("SD initialization timeout");
            rc = SD_ERR_UNSUPPORTED;
            goto err;
        }
    }
    if (type == SD_CARD_TYPE_SD2) {
        if ((status = do_cmd(CMD58_READ_OCR, 0)) != R1_READY_STATE) {
            TRACE("SD couldn't get card capacity. Status: %u", status);
            rc = SD_ERR_UNSUPPORTED;
            goto err;
        }
        if ((resp() & 0xC0) == 0xC0) {
            type = SD_CARD_TYPE_SDHC;
            TRACE("SD card initialized. HC");
        } else {
            TRACE("SD card initialized. V2");
        }
        for (int i = 0; i < 3; i++) {
            resp();
        }
    } else {
        TRACE("SD card initialized. V1");
    }

    if ((status = do_cmd(CMD9_SEND_CSD, 0)) != R1_READY_STATE) {
        TRACE("SD cold not execute CSD command. Status: %u", status);
        rc = SD_ERR_UNSUPPORTED;
        goto err;
    }
    CSD csd;
    if (read_single_block(csd, sizeof csd) != SD_ERR_OK) {
        TRACE("SD couldn't read CSD response");
        rc = SD_ERR_UNSUPPORTED;
        goto err;
    }
    sd.sectors = sd_sectors(csd);
    if (sd.sectors == 0) {
        TRACE("SD unsupported CSD");
        rc = SD_ERR_UNSUPPORTED;
        goto err;
    }

    if ((status = do_cmd(CMD16_SET_BLOCKLEN, BLOCK_SIZE)) != R1_READY_STATE) {
        TRACE("SD couldn't set block size. Status: %u", status);
        rc = SD_ERR_UNSUPPORTED;
        goto err;
    }

    cs_deselect();
    // set clock speed for data transfer
    spi_set_baudrate(sd.spi, 25 * 1000 * 1000);
    sd.connected = true;
    sd.type = type;
    return SD_ERR_OK;
err:
    cs_deselect();
    sd.connected = false;
    sd.type = SD_CARD_TYPE_UNKNOWN;
    return rc;
}

static sd_err sd_status2err(uint8_t status)
{
    if (status == R1_NO_RESPONSE) {
        return SD_ERR_NO_DEVICE;
    }
    if (status & R1_COM_CRC_ERROR) {
        return SD_ERR_CRC;
    }
    if (status & R1_ILLEGAL_COMMAND) {
        return SD_ERR_UNSUPPORTED;
    }
    return SD_ERR_PARAM;
}

static sd_err read_blocks(uint8_t *buf, uint64_t sectorNum, uint32_t sectorCnt)
{
    TRACE("SD reading sector. Num: %llu, Cnt: %lu", sectorNum, sectorCnt);
    if (sectorNum + sectorCnt > sd.sectors) {
        TRACE("SD invalid sector");
        return SD_ERR_PARAM;
    }
    if (!sd.connected) {
        TRACE("SD device is not initialized");
        return SD_ERR_NO_INIT;
    }

    uint32_t blockCnt = sectorCnt;
    uint64_t addr;
    uint8_t status;
    sd_err rc = SD_ERR_OK;
    if (sd.type == SD_CARD_TYPE_SDHC) {
        addr = sectorNum;
    } else {
        addr = sectorNum * BLOCK_SIZE;
    }

    cs_select();

    if (blockCnt > 1) {
        status = do_cmd(CMD18_READ_MULTIPLE_BLOCK, addr);
    } else {
        status = do_cmd(CMD17_READ_SINGLE_BLOCK, addr);
    }
    if (status != R1_READY_STATE) {
        TRACE("SD error while reading. Status: %u", status);
        rc = sd_status2err(status);
        goto out;
    }

    while (blockCnt--) {
        rc = read_single_block(buf, BLOCK_SIZE);
        if (rc != SD_ERR_OK) {
            goto out;
        }
        buf += BLOCK_SIZE;
    }

    if (sectorCnt > 1) {
        status = do_cmd(CMD12_STOP_TRANSMISSION, 0);
        if (status != R1_READY_STATE) {
            TRACE("SD error while stop transmission. Status: %u", status);
            rc = sd_status2err(status);
            goto out;
        }
    }
out:
    cs_deselect();
    return rc;
}

static sd_err write_block(const uint8_t *buf, uint32_t size, uint8_t token)
{
    uint8_t status;

    spi_write_blocking(sd.spi, &token, 1);
    spi_write_blocking(sd.spi, buf, size);

    uint16_t crc = crc16(buf, size);
    uint8_t byte = crc >> 8;
    spi_write_blocking(sd.spi, &byte, 1);
    byte = crc;
    spi_write_blocking(sd.spi, &byte, 1);

    status = resp();
    if ((status & 0x1F) != 0x05) {
        TRACE("SD block write failed. Status: %u", status);
        return SD_ERR_WRITE;
    }
    if (!wait_not_busy(SD_WRITE_TIMEOUT_MS)) {
        TRACE("SD write timeout");
        return SD_ERR_NO_RESPONSE;
    }
    return SD_ERR_OK;
}

static sd_err write_blocks(const uint8_t *buf, uint64_t sectorNum, uint32_t sectorCnt)
{
    TRACE("SD writung sector. Num: %llu, Cnt: %lu", sectorNum, sectorCnt);
    if (sectorNum + sectorCnt > sd.sectors) {
        TRACE("SD invalid sector");
        return SD_ERR_PARAM;
    }
    if (!sd.connected) {
        TRACE("SD device is not initialized");
        return SD_ERR_NO_INIT;
    }

    uint32_t blockCnt = sectorCnt;
    uint64_t addr;
    uint8_t status;
    sd_err rc = SD_ERR_OK;
    if (sd.type == SD_CARD_TYPE_SDHC) {
        addr = sectorNum;
    } else {
        addr = sectorNum * BLOCK_SIZE;
    }

    cs_select();
    if (blockCnt == 1) {
        if ((status = do_cmd(CMD24_WRITE_BLOCK, addr)) != R1_READY_STATE) {
            TRACE("SD error while writing. Status: %u", status);
            rc = sd_status2err(status);
            goto out;
        }
        write_block(buf, BLOCK_SIZE, SD_START_BLOCK);
    } else {
        do_acmd(ACMD23_SET_WR_BLK_ERASE_COUNT, blockCnt);

        if ((status = do_cmd(CMD25_WRITE_MULTIPLE_BLOCK, addr)) != R1_READY_STATE) {
            TRACE("SD error while writing multiple block. Status: %u", status);
            rc = sd_status2err(status);
            goto out;
        }
        while (blockCnt--) {
            if (write_block(buf, BLOCK_SIZE, 0xFC) != SD_ERR_OK) {
                break;
            }
            buf += BLOCK_SIZE;
        };
        const uint8_t byte = 0xFD;
        spi_write_blocking(sd.spi, &byte, 1);
    }

    uint16_t statusR2 = do_cmd(CMD13_SEND_STATUS, 0);
    statusR2 <<= 8;
    statusR2 |= resp();
    if (statusR2 == 0) {
        rc = SD_ERR_OK;
    } else if ((statusR2 & 0x01 << 1) || (statusR2 & 0x01 << 5)) {
        rc = SD_ERR_WRITE_PROTECTED;
    } else if (statusR2 & 0x01 << 11) {
        rc = SD_ERR_CRC;
    } else if ((statusR2 & 0x01 << 7) || (statusR2 & 0x01 << 13) || (statusR2 & 0x01 << 14)) {
        rc = SD_ERR_PARAM;
    } else {
        rc = SD_ERR_WRITE;
    }
    if (rc != SD_ERR_OK) {
        TRACE("SD write status: %u", statusR2);
    }
out:
    cs_deselect();
    return rc;
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

void sdcard_init(uint port, uint miso, uint mosi, uint sck, uint cs)
{
    if (port == 0) {
        sd.spi = spi0;
    } else {
        sd.spi = spi1;
    }
    sd.cs = cs;

    rtc_init();

    // initially set 100 kHz
    spi_init(sd.spi, 100 * 1000);

    gpio_set_function(miso, GPIO_FUNC_SPI);
    gpio_set_function(mosi, GPIO_FUNC_SPI);
    gpio_set_function(sck, GPIO_FUNC_SPI);
    gpio_pull_up(miso);

    gpio_init(cs);
    gpio_set_dir(cs, GPIO_OUT);
    gpio_put(cs, 1);

    ensure_connect();
}
