#include "rom.h"
#include "err.h"
#include "fpga_api.h"
#include <errno.h>
#include <ff.h>
#include <stdbool.h>

#define SIZE_8K 0x2000
#define SIZE_16K 0x4000

static bool file_reader(uint8_t *data, uint32_t size, void *arg)
{
    FIL *fp = arg;
    UINT br;
    return f_read(fp, data, size, &br) == FR_OK && br == size;
}

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
        prg_size |= header[9] << 8u & 0xF00;
        chr_size |= header[9] << 4u & 0xF00;
    }
    prg_size *= SIZE_16K;
    chr_size *= SIZE_8K;

    fpga_api_load(0, prg_size, file_reader, &fp);
    fpga_api_load(prg_size, chr_size, file_reader, &fp);
    fpga_api_launch();
out:
    f_close(&fp);
    return err;
}
