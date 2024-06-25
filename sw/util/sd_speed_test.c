#include "ff.h"
#include "sdcard.h"
#include <pico/stdlib.h>
#include <stdio.h>
#include <stdlib.h>

#define SD_SPI_PORT 0
#define SD_PIN_SCK 2
#define SD_PIN_MOSI 3
#define SD_PIN_MISO 4
#define SD_PIN_CS 5

#define SDIO_SCK 18
#define SDIO_CMD 19
#define SDIO_D0 20

#define error(...)           \
    do {                     \
        printf(__VA_ARGS__); \
        printf("\n");        \
        return 0;            \
    } while (0)

#define BUF_SIZE 512
#define FILE_SIZE 5 * 1024 * 1024

int main()
{
    stdio_init_all();

    sdcard_init(SDIO_SCK, SDIO_CMD, SDIO_D0);
    // sdcard_init(SD_SPI_PORT, SD_PIN_MISO, SD_PIN_MOSI, SD_PIN_SCK, SD_PIN_CS);

    FATFS fs;
    FIL fp;
    UINT sz;
    FRESULT res;

    res = f_mount(&fs, "0:", 1);
    if (res != FR_OK) {
        error("mount %d", res);
    }

    uint8_t buf[BUF_SIZE];
    for (int i = 0; i < BUF_SIZE; i++) {
        buf[i] = rand() % 255;
    }

    res = f_open(&fp, "0:/bench.dat", FA_OPEN_ALWAYS | FA_READ | FA_WRITE);
    if (res != FR_OK) {
        error("f_open %d", res);
    }

    printf("starting write test...\n");
    UINT n = 0;
    absolute_time_t start = get_absolute_time();
    while (n < FILE_SIZE) {
        res = f_write(&fp, buf, BUF_SIZE, &sz);
        if (res != FR_OK || sz != BUF_SIZE) {
            error("f_write %d", res);
        }
        n += BUF_SIZE;
    }
    f_sync(&fp);
    int64_t t = absolute_time_diff_us(start, get_absolute_time());
    double diff = t / 1000.0 / 1000.0;
    printf("write speed: %.2f Mb/s\n", (n / diff) / 1024.0 / 1024.0);

    f_lseek(&fp, 0);
    printf("starting read test...\n");
    start = get_absolute_time();
    for (UINT i = 0; i < n; i += BUF_SIZE) {
        res = f_read(&fp, buf, BUF_SIZE, &sz);
        if (res != FR_OK || sz != BUF_SIZE) {
            error("f_read %d", res);
        }
    }
    t = absolute_time_diff_us(start, get_absolute_time());
    diff = t / 1000.0 / 1000.0;
    printf("read speed: %.2f Mb/s\n", (n / diff) / 1024.0 / 1024.0);

    f_close(&fp);
}
