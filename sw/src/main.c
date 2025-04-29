#include "rom.h"
#include <ff.h>
#include <gpio.h>
#include <log.h>
#include <soc.h>
#include <string.h>

LOG_MODULE(main);

void upload()
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
            }
        }
        f_closedir(&dir);
    }

    f_unmount("/SD");

    led_on(false);
}

int main()
{
    hw_init();
    set_button_callback(upload);

    for (;;) {
        gpio_pull();
    }

    return 0;
}
