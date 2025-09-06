#include "fpga_cfg.h"
#include "gfx.h"
#include "rom.h"
#include <ff.h>
#include <gpio.h>
#include <log.h>
#include <soc.h>
#include <string.h>

LOG_MODULE(main);

static void fpga_file_cfg(const char *filename)
{
    FIL fp;
    UINT sz;
    uint8_t buf[512];

    if (f_open(&fp, filename, FA_READ) != FR_OK) {
        goto out;
    }
    if (fpga_cfg_start() != 0) {
        goto out;
    }
    while (!f_eof(&fp)) {
        if (f_read(&fp, buf, sizeof(buf), &sz) != FR_OK) {
            goto out;
        }
        if (fpga_cfg_write(buf, sz) != 0) {
            goto out;
        }
    }
    fpga_cfg_done();
out:
    f_close(&fp);
}

static void upload()
{
    LOG_INF("Uploading ROM...");
    led_on(true);

    FATFS fs;
    FRESULT res;
    DIR dir;
    FILINFO fno;

    f_mount(&fs, "/SD", 1);

    res = f_opendir(&dir, "/");
    if (res == FR_OK) {
        for (;;) {
            res = f_readdir(&dir, &fno);
            if (res != FR_OK || fno.fname[0] == 0)
                break;
            if (!(fno.fattrib & AM_DIR)) {
                char *ext = strrchr(fno.fname, '.');
                if (ext != NULL && strcmp(ext, ".nes") == 0) {
                    rom_load(fno.fname);
                    break;
                }
                /*if (ext != NULL && strcmp(ext, ".bit") == 0) {
                    fpga_file_cfg(fno.fname);
                    break;
                }*/
            }
        }
        f_closedir(&dir);
    }

    f_unmount("/SD");

    led_on(false);
}

static void switch_led()
{
    static bool on = false;
    on = !on;
    led_on(on);
}

int main()
{
    hw_init();
    set_button_callback(upload);

    int i = 0;

    for (;;) {
        gpio_pull();
        // led_on(HAL_GPIO_ReadPin(GPIO_IRQ_PORT, GPIO_IRQ_PIN) == GPIO_PIN_SET);
        // switch_led();
        // delay_ms(500);

        /*gfx_clear();
        gfx_text(i, 100, "Hello, World!", 2);
        i++;
        if (i > 200)
            i = 0;
        gfx_refresh();
        delay_ms(50);*/
    }

    return 0;
}
