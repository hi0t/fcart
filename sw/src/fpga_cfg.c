#include "fpga_cfg.h"
#include "log.h"
#include <errno.h>
#include <jtag.h>
#include <stdbool.h>

#define IRLENGTH 10

LOG_MODULE(fpga_cfg);

static bool scan();

int fpga_cfg_begin()
{
    jtag_resume();
    if (!scan()) {
        LOG_ERR("FPGA not found");
        return -ENODEV;
    }

    return 0;
}

int fpga_cfg_put(uint8_t *data, uint32_t len)
{
    return 0;
}

int fpga_cfg_end()
{
    jtag_suspend();

    return 0;
}

static bool scan()
{
    uint8_t tx[4] = { 0x06 };
    uint8_t rx[4] = { 0 };
    jtag_reset();
    jtag_shift_ir(tx, IRLENGTH, JTAG_RUN_TEST_IDLE);
    jtag_shift_dr(NULL, rx, 32, JTAG_RUN_TEST_IDLE);

    uint32_t id = rx[0] | (rx[1] << 8u) | (rx[2] << 16u) | (rx[3] << 24u);
    LOG_INF("FPGA ID: 0x%08x", id);
    return id == 0x0318a0dd;
}
