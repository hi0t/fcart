#include "fpga.h"
#include "sdio.h"

void fpga_init()
{
    sdio_init(10, 11, 12, 100);
}

void fpga_write_prg(uint32_t address, uint32_t size, fpga_reader_cb cb, void *arg)
{
    for (uint32_t i = 0; i < (1 << (size - 1)); i++) {
        uint16_t data;
        if (!cb(&data, arg)) {
            return;
        }
        sdio_cmd_R1(1, i << 16u | data, NULL);
    }
}

void fpga_write_chr(uint32_t address, uint32_t size, fpga_reader_cb cb, void *arg)
{
    for (uint32_t i = 0; i < (1 << (size - 1)); i++) {
        uint16_t data;
        if (!cb(&data, arg)) {
            return;
        }
        sdio_cmd_R1(2, i << 16u | data, NULL);
    }
}

void fpga_launch()
{
    sdio_cmd_R1(3, 0, NULL);
}
