#include "ff.h"
#include "pico/stdlib.h"
#include "sdcard.h"
#include <stdio.h>

#define SD_SPI_PORT 0
#define SD_PIN_SCK 2
#define SD_PIN_MOSI 3
#define SD_PIN_MISO 4
#define SD_PIN_CS 5

int main()
{
    stdio_init_all();

    sdcard_init(SD_SPI_PORT, SD_PIN_MISO, SD_PIN_MOSI, SD_PIN_SCK, SD_PIN_CS);

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

    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);

    while (true) {
        gpio_put(PICO_DEFAULT_LED_PIN, 1);
        sleep_ms(1000);
        gpio_put(PICO_DEFAULT_LED_PIN, 0);
        sleep_ms(1000);
    }
}
