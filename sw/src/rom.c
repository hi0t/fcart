#include "rom.h"
#include "err.h"
#include "fpga_api.h"
#include <errno.h>
#include <ff.h>
#include <stddef.h>

#define SIZE_8K 0x2000
#define SIZE_16K 0x4000
#define SIZE_32K 0x8000

#define max(a, b) ((a) > (b) ? (a) : (b))

static bool file_reader(uint8_t *data, uint32_t size, void *arg);
static uint32_t exp_size(uint32_t size);
static uint32_t shift_size(uint8_t shift);
static uint16_t choose_mapper(uint16_t id);
static uint8_t get_chr_off(uint32_t prg_size);

int rom_load(const char *filename)
{
    FIL fp;
    FRESULT rc;
    UINT sz;
    int err = 0;

    uint8_t header[16];
    if ((rc = f_open(&fp, filename, FA_READ)) != FR_OK) {
        err = -fresult_to_errno(rc);
        goto out;
    }
    if ((rc = f_read(&fp, header, sizeof(header), &sz) != FR_OK)) {
        err = -fresult_to_errno(rc);
        goto out;
    }

    if (!(header[0] == 'N' && header[1] == 'E' && header[2] == 'S' && header[3] == 0x1A)) {
        err = -EINVAL;
        goto out;
    }

    bool nes20 = (header[7] & 0x0C) == 0x08;

    uint32_t prg_size = header[4];
    uint32_t chr_size = header[5];
    uint32_t chr_ram_size = 0;
    uint16_t mapper_id = (header[7] & 0xF0) | (header[6] >> 4U);

    if (nes20) {
        if ((header[9] & 0x0F) == 0x0F) {
            prg_size = exp_size(prg_size);
        } else {
            prg_size |= header[9] << 8U & 0xF00;
            prg_size *= SIZE_16K;
        }

        if ((header[9] & 0xF0) == 0xF0) {
            chr_size = exp_size(chr_size);
        } else {
            chr_size |= header[9] << 4U & 0xF00;
            chr_size *= SIZE_8K;
        }

        mapper_id |= (header[8] & 0x0F) << 8U;

        chr_ram_size = shift_size(header[11] & 0x0F);
    } else {
        prg_size *= SIZE_16K;
        chr_size *= SIZE_8K;
    }

    uint8_t mirroring = header[6] & 0x01;
    uint8_t has_chr_ram = nes20 ? chr_ram_size > 0 : chr_size == 0;
    uint8_t chr_off = get_chr_off(prg_size);

    fpga_api_write_reg(FPGA_REG_LAUNCHER, 1 << 1U); // prelaunch
    for (;;) {
        if ((fpga_api_ev_reg() & (1 << 8U)) == 0) { // waiting for loader to exit
            break;
        }
    }
    fpga_api_write_mem(0, prg_size, file_reader, &fp);
    fpga_api_write_mem(1U << chr_off, chr_size, file_reader, &fp);

    uint32_t mapper_args = choose_mapper(mapper_id);
    mapper_args |= chr_off << 5U;
    mapper_args |= mirroring << 10U;
    mapper_args |= has_chr_ram << 11U;

    fpga_api_write_reg(FPGA_REG_MAPPER, mapper_args);
    //   mapper args:
    //   11|10|9|8|7|6|5|4|3|2|1|0
    //    |  | | | | | | | | | | |
    //    |  | | | | | | +-+-+-+-+- mapper ID (5 bits)
    //    |  | +-+-+-+-+----------- CHR offset
    //    |  +--------------------- mirroring: 0 = horizontal, 1 = vertical
    //    +------------------------ has CHR RAM
out:
    f_close(&fp);
    return err;
}

static bool file_reader(uint8_t *data, uint32_t size, void *arg)
{
    FIL *fp = arg;
    UINT br;
    return f_read(fp, data, size, &br) == FR_OK && br == size;
}

static uint32_t exp_size(uint32_t size)
{
    uint32_t exp = size >> 2U;
    uint32_t mult = size & 0x03;
    exp = exp > 32 ? 32 : exp;
    return (1U << exp) * (mult * 2 + 1);
}

static uint32_t shift_size(uint8_t shift)
{
    if (shift == 0) {
        return 0;
    }
    return 64U << shift;
}

// translate NES mapper ID to FPGA mapper ID
static uint16_t choose_mapper(uint16_t id)
{
    switch (id) {
    case 0:
        return 1;
    case 1:
        return 2;
    case 2:
        return 3;
    case 3:
        return 4;
    case 24:
        return 5;
    case 26:
        return 5;
    default:
        return 0;
    }
}

static uint8_t get_chr_off(uint32_t prg_size)
{
    uint8_t off = 0;
    while ((1U << off) < prg_size) {
        off++;
        if (off > 32) {
            return 0; // error, prg_size too large
        }
    }
    return off;
}
