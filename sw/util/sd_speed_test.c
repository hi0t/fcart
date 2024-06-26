#include "ff.h"
#include "sdcard.h"
#include <hardware/structs/ioqspi.h>
#include <hardware/structs/sio.h>
#include <hardware/sync.h>
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

#define error(...)           \
    do {                     \
        printf(__VA_ARGS__); \
        printf("\n");        \
        return 0;            \
    } while (0)

#define BUF_SIZE 512
#define FILE_SIZE 10 * 1024 * 1024

bool __no_inline_not_in_flash_func(get_bootsel_button)()
{
    const uint CS_PIN_INDEX = 1;
    uint32_t flags = save_and_disable_interrupts();

    hw_write_masked(&ioqspi_hw->io[CS_PIN_INDEX].ctrl,
        GPIO_OVERRIDE_LOW << IO_QSPI_GPIO_QSPI_SS_CTRL_OEOVER_LSB,
        IO_QSPI_GPIO_QSPI_SS_CTRL_OEOVER_BITS);

    for (volatile int i = 0; i < 1000; ++i)
        ;
    bool button_state = !(sio_hw->gpio_hi_in & (1u << CS_PIN_INDEX));

    hw_write_masked(&ioqspi_hw->io[CS_PIN_INDEX].ctrl,
        GPIO_OVERRIDE_NORMAL << IO_QSPI_GPIO_QSPI_SS_CTRL_OEOVER_LSB,
        IO_QSPI_GPIO_QSPI_SS_CTRL_OEOVER_BITS);

    restore_interrupts(flags);

    return button_state;
}

int main()
{
    stdio_init_all();

    sdcard_init(SDIO_SCK, SDIO_CMD, SDIO_D0);
    // sdcard_init(SD_SPI_PORT, SD_PIN_MISO, SD_PIN_MOSI, SD_PIN_SCK, SD_PIN_CS);

again:
    while (true) {
        if (get_bootsel_button()) {
            break;
        }
        sleep_ms(100);
    }

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
    res = f_sync(&fp);
    if (res != FR_OK) {
        error("f_sync %d", res);
    }
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
    f_unmount("0:");

    bool again_f = false;
    while (true) {
        if (get_bootsel_button()) {
            if (again_f) {
                goto again;
            } else {
                again_f = true;
                sleep_ms(5000);
                printf("press the button again to restart the test\n");
            }
        }
        sleep_ms(100);
    }
}
