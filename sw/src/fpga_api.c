#include "fpga_api.h"
#include <errno.h>
#include <qspi.h>
#include <stddef.h>

enum {
    START_LOAD = 1,
    LOAD_DATA,
    LAUNCH
};

int fpga_api_load(uint32_t address, uint32_t size, fpga_api_reader_cb cb, void *arg)
{
    uint8_t buf[512];
    uint32_t remain = size;

    qspi_send(START_LOAD, (uint8_t *)&address, 3);

    while (remain > 0) {
        uint32_t chunk = remain > sizeof(buf) ? sizeof(buf) : remain;
        if (!cb(buf, chunk, arg)) {
            return -EIO;
        }
        qspi_send(LOAD_DATA, buf, chunk);
        remain -= chunk;
    }

    return 0;
}

int fpga_api_launch()
{
    qspi_send(LAUNCH, NULL, 0);
    return 0;
}
