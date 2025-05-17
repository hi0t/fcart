#include "fpga_cfg.h"
#include "log.h"
#include <spi.h>

LOG_MODULE(fpga_cfg);

static int get_status();

int fpga_cfg_put(uint8_t *data, uint32_t len)
{
    get_status();
    return 0;
}

static int get_status()
{
    uint8_t cmd = 0x00;
    uint8_t status[2];
    int rc;

    spi_begin();
    if ((rc = spi_send(&cmd, 1)) != 0) {
        goto out;
    }
    if ((rc = spi_send(status, sizeof(status))) != 0) {
        goto out;
    }
out:
    spi_end();
    return rc;
}
