#include "fpga_cfg.h"
#include "log.h"
#include <spi.h>

#define READ_STATUS { 0x3C, 0x00, 0x00, 0x00 }
#define READ_DEIVCE_ID { 0x9E, 0x00, 0x00, 0x9E }

LOG_MODULE(fpga_cfg);

uint32_t fpga_cfg_device_id()
{
    uint8_t tx[] = READ_DEIVCE_ID;
    uint8_t rx[4];
    uint32_t id = 0;

    // spi_transmit_receive(tx, rx, sizeof(tx));

    return id;
}
