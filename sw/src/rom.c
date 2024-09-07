#include "rom.h"
#include "ff.h"
#include "fpga.h"
#include "sdio.h"
#include <stdbool.h>

#define SIZE_8K 0x2000
#define SIZE_16K 0x4000

static bool file_reader(uint16_t *data, void *arg)
{
    FIL *fp = arg;
    UINT sz;
    return f_read(fp, data, 2, &sz) == FR_OK;
}

void rom_push(const char *path)
{
    FIL fp;
    FRESULT r;
    UINT sz;

    uint8_t header[16];
    if ((r = f_open(&fp, path, FA_READ)) != FR_OK) {
        goto out;
    }
    if ((r = f_read(&fp, header, sizeof(header), &sz) != FR_OK)) {
        goto out;
    }

    if (!(header[0] == 'N' && header[1] == 'E' && header[2] == 'S' && header[3] == 0x1A)) {
        goto out;
    }
    bool nes20 = (header[7] & 0x0C) == 0x08;

    uint32_t prg_size = header[4];
    uint32_t chr_size = header[5];
    if (nes20) {
        prg_size |= header[9] << 8u & 0xF00;
        chr_size |= header[9] << 4u & 0xF00;
    }
    prg_size *= SIZE_16K;
    chr_size *= SIZE_8K;

    fpga_load();
    fpga_write_prg(prg_size, file_reader, &fp);
    fpga_write_chr(chr_size, file_reader, &fp);
    fpga_launch();
out:
    f_close(&fp);
}
