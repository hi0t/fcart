#include "crc.h"
#include "diskio.h"
#include "hardware/spi.h"
#include "pico/stdlib.h"
#include "sdcard.h"
#include "trace.h"

#define PACKET_SIZE 6
#define SD_INIT_TIMEOUT_MS 1000
#define SD_READ_TIMEOUT_MS 500
#define BLOCK_SIZE 512

typedef enum {
    CMD0_GO_IDLE_STATE = 0,
    CMD8_SEND_IF_COND = 8,
    CMD12_STOP_TRANSMISSION = 12,
    CMD16_SET_BLOCKLEN = 16,
    CMD17_READ_SINGLE_BLOCK = 17,
    CMD18_READ_MULTIPLE_BLOCK = 18,
    CMD55_APP_CMD = 55,
    CMD58_READ_OCR = 58,
    CMD59_CRC_ON_OFF = 59,

    ACMD41_SD_SEND_OP_COND = 41
} sd_cmd;

typedef enum {
    SD_CARD_TYPE_UNKNOWN = 0,
    SD_CARD_TYPE_SD1,
    SD_CARD_TYPE_SD2,
    SD_CARD_TYPE_SDHC
} sd_type;

#define R1_READY_STATE 0
#define R1_IDLE_STATE (1 << 0)
#define R1_ERASE_RESET (1 << 1)
#define R1_ILLEGAL_COMMAND (1 << 2)
#define R1_COM_CRC_ERROR (1 << 3)
#define R1_ERASE_SEQUENCE_ERROR (1 << 4)
#define R1_ADDRESS_ERROR (1 << 5)
#define R1_PARAMETER_ERROR (1 << 6)

struct sdcard {
    spi_inst_t *spi;
    uint cs;
    bool connected;
    sd_type type;
};

static struct sdcard sd;

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

static uint8_t do_cmd(sd_cmd cmd, uint32_t arg)
{
    TRACE("SD send command %u\n", cmd);

    uint8_t res;
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

    for (int i = 0; ((res = resp()) & 0x80) && i < 0x10; i++)
        ;
    return res;
}

static uint8_t do_acmd(sd_cmd cmd, uint32_t arg)
{
    do_cmd(CMD55_APP_CMD, 0);
    return do_cmd(cmd, arg);
}

static void ensure_connect()
{
    if (sd.connected) {
        return;
    }

    TRACE("SD connecting...\n");

    spi_set_baudrate(sd.spi, 400 * 1000);

    gpio_put(sd.cs, 1);
    // send at least 74 clock cycles
    uint8_t one = 0xFF;
    for (int i = 0; i < 10; i++) {
        spi_write_blocking(sd.spi, &one, 1);
    }

    cs_select();

    absolute_time_t timeout = make_timeout_time_ms(SD_INIT_TIMEOUT_MS);
    while (do_cmd(CMD0_GO_IDLE_STATE, 0) != R1_IDLE_STATE) {
        if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            goto err;
        }
    }

    sd_type type;
    uint8_t status;
    if ((do_cmd(CMD8_SEND_IF_COND, 0x1AA) & R1_ILLEGAL_COMMAND)) {
        type = SD_CARD_TYPE_SD1;
    } else {
        for (int i = 0; i < 4; i++) {
            status = resp();
        }
        if (status != 0XAA) {
            goto err;
        }
        type = SD_CARD_TYPE_SD2;
    }

    if (do_cmd(CMD59_CRC_ON_OFF, 1) != R1_IDLE_STATE) {
        goto err;
    }

    uint32_t arg = type == SD_CARD_TYPE_SD2 ? 0X40000000 : 0;
    timeout = make_timeout_time_ms(SD_INIT_TIMEOUT_MS);
    while (do_acmd(ACMD41_SD_SEND_OP_COND, arg) != R1_READY_STATE) {
        if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            goto err;
        }
    }
    if (type == SD_CARD_TYPE_SD2) {
        if (do_cmd(CMD58_READ_OCR, 0) != R1_READY_STATE) {
            goto err;
        }
        if ((resp() & 0xC0) == 0xC0) {
            type = SD_CARD_TYPE_SDHC;
        }
        for (int i = 0; i < 3; i++) {
            resp();
        }
    }

    if (do_cmd(CMD16_SET_BLOCKLEN, BLOCK_SIZE) != R1_READY_STATE) {
        goto err;
    }

    cs_deselect();
    spi_set_baudrate(sd.spi, 25 * 1000 * 1000);
    sd.connected = true;
    sd.type = type;
    TRACE("SD connected\n");
    return;
err:
    cs_deselect();
    sd.connected = false;
    sd.type = SD_CARD_TYPE_UNKNOWN;
    TRACE("SD connect fail\n");
}

static bool wait_start_block()
{
    absolute_time_t timeout = make_timeout_time_ms(SD_READ_TIMEOUT_MS);
    while (resp() != 0xFE) {
        if (absolute_time_diff_us(get_absolute_time(), timeout) < 0) {
            return false;
        }
    }
    return true;
}

static int read_single_block(uint8_t *buf, uint32_t size)
{
    if (!wait_start_block()) {
        return 0;
    }

    int r = spi_read_blocking(sd.spi, 0xFF, buf, size);

    uint16_t crc;
    crc = (resp() << 8);
    crc |= resp();

    uint16_t checksum = crc16(buf, size);
    if (checksum != crc) {
        return crc;
    }
    return r;
}

static void read_blocks(uint8_t *buf, uint64_t sectorNum, uint32_t sectorCnt)
{
    uint32_t blockCnt = sectorCnt;
    uint64_t addr;
    if (sd.type == SD_CARD_TYPE_SDHC) {
        addr = sectorNum;
    } else {
        addr = sectorNum * BLOCK_SIZE;
    }

    cs_select();

    if (blockCnt > 1) {
        do_cmd(CMD18_READ_MULTIPLE_BLOCK, addr);
    } else {
        do_cmd(CMD17_READ_SINGLE_BLOCK, addr);
    }

    while (blockCnt) {
        read_single_block(buf, BLOCK_SIZE);
        buf += BLOCK_SIZE;
        --blockCnt;
    }

    if (sectorCnt > 1) {
        do_cmd(CMD12_STOP_TRANSMISSION, 0);
    }

    cs_deselect();
}

DSTATUS disk_status(BYTE pdrv)
{
    return sd.connected ? 0 : STA_NOINIT;
}

DSTATUS disk_initialize(BYTE pdrv)
{
    ensure_connect();
    return 0;
}

DRESULT disk_read(BYTE pdrv, BYTE *buff, LBA_t sector, UINT count)
{
    read_blocks(buff, sector, count);
    return RES_OK;
}

DRESULT disk_write(BYTE pdrv, const BYTE *buff, LBA_t sector, UINT count)
{
    return RES_PARERR;
}

DRESULT disk_ioctl(BYTE pdrv, BYTE cmd, void *buff)
{
    return RES_PARERR;
}

void sdcard_init(uint port, uint miso, uint mosi, uint sck, uint cs)
{
    if (sd.connected) {
        return;
    }

    if (port == 0) {
        sd.spi = spi0;
    } else {
        sd.spi = spi1;
    }
    sd.cs = cs;

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
