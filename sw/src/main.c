#include "rom.h"
#include <ff.h>
#include <led.h>
#include <log.h>
#include <soc.h>
#include <string.h>

LOG_MODULE(main);

int main()
{
    hw_init();

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

    for (;;) {
        led_toggle();
        delay_ms(500);
    }

    return 0;
}
