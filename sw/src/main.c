#include "sdio.h"
#include <pico/stdlib.h>
#include <stdio.h>

static uint8_t led;

static void inc_led()
{
    led++;
    uint32_t reply;
    sdio_cmd_R1(1, led, &reply);
}

int main()
{
    stdio_init_all();

    sdio_init(10, 11, 12, 100);

    gpio_init(4);
    gpio_set_dir(4, GPIO_IN);

    while (true) {
        if (!gpio_get(4)) {
            sleep_ms(100);
            if (!gpio_get(4)) {
                inc_led();
            }
        }
    }
}
