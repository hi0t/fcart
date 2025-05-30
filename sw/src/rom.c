#include "rom.h"
#include "err.h"
#include "fpga_api.h"
#include <errno.h>
#include <ff.h>
#include <stdbool.h>

#define SIZE_8K 0x2000
#define SIZE_16K 0x4000
#define SIZE_32K 0x8000

#define max(a, b) ((a) > (b) ? (a) : (b))

static bool file_reader(uint8_t *data, uint32_t size, void *arg);
static uint32_t exp_size(uint32_t size);

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
    } else {
        prg_size *= SIZE_16K;
        chr_size *= SIZE_8K;
    }

    uint8_t mirroring = header[6] & 0x01;

    uint32_t prg_off = prg_size > SIZE_32K ? 0 : SIZE_32K - prg_size;
    uint32_t chr_off = max(SIZE_32K, prg_size);

    fpga_api_load(prg_off, prg_size, file_reader, &fp);
    fpga_api_load(chr_off, chr_size, file_reader, &fp);
    fpga_api_launch((mirroring << 8U) | (chr_off >> 13U));
    //    rom info: 876543210
    //              |||||||||
    //              |++++++++- chr offset shifted by 13 (ppu cart width)
    //              +--------- mirroring: 0 = horizontal, 1 = vertical
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
