#include "ff.h"
#include "sdcard.h"
#include "sdio.h"
#include <pico/stdlib.h>
#include <stdio.h>
#include <stdlib.h>

#define SD_SPI_PORT 0
#define SD_PIN_SCK 18
#define SD_PIN_MOSI 19
#define SD_PIN_MISO 20
#define SD_PIN_CS 23

#define SDIO_SCK 18
#define SDIO_CMD 19
#define SDIO_D0 20

int main()
{
    stdio_init_all();

    sdcard_init(SDIO_SCK, SDIO_CMD, SDIO_D0);
    // sdcard_init(SD_SPI_PORT, SD_PIN_MISO, SD_PIN_MOSI, SD_PIN_SCK, SD_PIN_CS);

    FRESULT res;
    DIR dir;
    FILINFO fno;
    int nfile, ndir;
    FATFS fs;

    f_mount(&fs, "0:", 1);
    res = f_opendir(&dir, "0:/");
    if (res == FR_OK) {
        nfile = ndir = 0;
        for (;;) {
            res = f_readdir(&dir, &fno);
            if (res != FR_OK || fno.fname[0] == 0)
                break;
            if (fno.fattrib & AM_DIR) {
                printf("   <DIR>   %s\n", fno.fname);
                ndir++;
            } else {
                printf("%10llu %s\n", fno.fsize, fno.fname);
                nfile++;
            }
        }
        f_closedir(&dir);
        printf("%d dirs, %d files.\n", ndir, nfile);
    }

    gpio_init(25);
    gpio_set_dir(25, GPIO_OUT);

    while (true) {
        // gpio_put(25, 1);
        sleep_ms(1000);
        // gpio_put(25, 0);
        // sleep_ms(1000);
    }
}
