#include "ui.h"
#include <ff.h>
#include <gpio.h>
#include <soc.h>
#include <tusb.h>

int main()
{
    hw_init();
    ui_init();

    for (;;) {
        gpio_poll();
        ui_poll();
        tud_task();
    }

    return 0;
}
