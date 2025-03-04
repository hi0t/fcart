#include <assert.h>
#include <ff.h>
#include <led.h>
#include <log.h>
#include <qspi.h>
#include <soc.h>
#include <string.h>

LOG_MODULE(main);

int main()
{
    hw_init();

    /*FATFS fs;
    FRESULT rc = f_mount(&fs, "/SD", 0);
    assert(rc == FR_OK);

    DIR dir;
    FILINFO fno;
    rc = f_opendir(&dir, "/");
    assert(rc == FR_OK);
    for (;;) {
        rc = f_readdir(&dir, &fno);
        if (rc != FR_OK || fno.fname[0] == 0)
            break;
        if (fno.fattrib & AM_DIR) {
            printf("   <DIR>   %s\n", fno.fname);
        } else {
            printf("%10lu %s\n", (uint32_t)fno.fsize, fno.fname);
        }
    }
    f_closedir(&dir);

    FIL fil;
    UINT bw;
    rc = f_open(&fil, "/logfile.txt", FA_WRITE | FA_OPEN_ALWAYS);
    assert(rc == FR_OK);
    f_write(&fil, "test\n", 5, &bw);
    f_close(&fil);*/

    uint8_t data[512];
    memset(data, 0xf, sizeof(data));
    qspi_send(0x9F, data, sizeof(data));

    for (;;) {
        led_toggle();
        delay_ms(1000);
    }

    return 0;
}
