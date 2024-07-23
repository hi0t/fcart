#include "sdio.h"
#include <hardware/clocks.h>
#include <pico/stdlib.h>
#include <stdio.h>
#include <stdlib.h>

int main()
{
    stdio_init_all();
    clock_gpio_init_int_frac(25, CLOCKS_CLK_GPOUT3_CTRL_AUXSRC_VALUE_CLK_SYS, 2, 0); // 62.5 MHz FPGA clock

    sdio_init(10, 11, 12, 100);

    sleep_ms(5000);

    printf("sending...\n");
    uint32_t reply;
    uint8_t buf[1024];
    for (int i = 0; i < sizeof(buf); i += 2) {
        buf[i] = rand() >> 16;
        buf[i + 1] = rand() >> 16;
        uint16_t addr = i / 2;
        uint16_t data = buf[i + 1] << 8u | buf[i];
        printf("0x%04x: 0x%04x\n", addr, data);
        sdio_cmd_R1(2, data << 16u | addr, &reply);
    }

    sleep_ms(5000);

    printf("receiving...\n");
    bool valid = true;
    for (int i = 0; i < sizeof(buf); i += 2) {
        uint16_t addr = i / 2;
        sdio_cmd_R1(1, addr, &reply);
        uint16_t data = buf[i + 1] << 8u | buf[i];
        if (reply != data) {
            valid = false;
            break;
        }
        printf("0x%04x: 0x%04x\n", addr, data);
    }
    printf("\n\nvalid: %d\n", valid);

    while (true) {
        sleep_ms(100);
    }
}
