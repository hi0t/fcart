#include "fpga_mgmt.h"
#include "qspi.h"

#include <zephyr/logging/log.h>

static const struct device *const qspi = DEVICE_DT_GET(FCART_QSPI_NODE);

LOG_MODULE_REGISTER(fpga_mgmt);

void fpga_mgmt_load(off_t addr, void *data, size_t size)
{
    const uint8_t arr[] = { 0x00, 0x11, 0x22, 0x33 };
    qspi_send(qspi, 0x0A, arr, sizeof(arr));
}
