#include "fpga_cfg.h"
#include "joypad.h"
#include "ui.h"
#include <ff.h>
#include <gpio.h>
#include <soc.h>

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

static void switch_led()
{
    static bool on = false;
    on = !on;
    led_on(on);
}

int main()
{
    hw_init();
    ui_init();

    for (;;) {
        gpio_poll();
        joypad_poll();
    }

    return 0;
}
