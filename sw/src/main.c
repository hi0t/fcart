#include "ff.h"
#include "fpga.h"
#include "fpga_flash.h"
#include "rom.h"
#include "sdcard.h"
#include "sdio.h"
#include <pico/stdlib.h>
#include <string.h>

#define SD_SPI_PORT 0
#define SD_PIN_SCK 2
#define SD_PIN_MOSI 3
#define SD_PIN_MISO 4
#define SD_PIN_CS 5

int main()
{
    stdio_init_all();

    sdcard_init(SD_SPI_PORT, SD_PIN_MISO, SD_PIN_MOSI, SD_PIN_SCK, SD_PIN_CS);
    fpga_init();

#ifdef ENABLE_FPGA_FLASH
    fpga_flash();
#endif

    FATFS fs;
    FRESULT res;
    DIR dir;
    FILINFO fno;

    f_mount(&fs, "0:", 1);

    res = f_opendir(&dir, "0:/");
    if (res == FR_OK) {
        for (;;) {
            res = f_readdir(&dir, &fno);
            if (res != FR_OK || fno.fname[0] == 0)
                break;
            if (!(fno.fattrib & AM_DIR)) {
                char *ext = strrchr(fno.fname, '.');
                if (ext != NULL && strcmp(ext, ".nes") == 0) {
                    rom_push(fno.fname);
                    break;
                }
            }
        }
        f_closedir(&dir);
    }

    f_unmount("0:");

    while (true) {
        sleep_ms(100);
    }
}
