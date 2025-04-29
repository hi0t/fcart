#include "fpga_api.h"
#include <errno.h>
#include <spi.h>
#include <stddef.h>

enum {
    LOAD_DATA = 1,
    LAUNCH
};

int fpga_api_load(uint32_t address, uint32_t size, fpga_api_reader_cb cb, void *arg)
{
    uint8_t buf[512];
    uint32_t remain = size;
    int rc = 0;

    spi_begin();

    buf[0] = LOAD_DATA;
    if ((rc = spi_send(buf, 1)) != 0) {
        goto out;
    }
    if ((rc = spi_send((uint8_t *)&address, 3)) != 0) {
        goto out;
    }

    while (remain > 0) {
        uint16_t chunk = remain > sizeof(buf) ? sizeof(buf) : remain;
        if (!cb(buf, chunk, arg)) {
            rc = -EIO;
            goto out;
        }
        // TODO: make parallel transfer
        if ((rc = spi_send(buf, chunk)) != 0) {
            goto out;
        }
        remain -= chunk;
    }
out:
    spi_end();
    return rc;
}

int fpga_api_launch()
{
    uint8_t buf = LAUNCH;
    int rc;

    spi_begin();
    rc = spi_send(&buf, 1);
    spi_end();

    return rc;
}
