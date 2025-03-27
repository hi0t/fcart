#include "fpga.h"
#include "internal.h"
#include "log.h"

#define SPI_TIMEOUT 100
#define READ_STATUS { 0x3C, 0x00, 0x00, 0x00 }
#define READ_DEIVCE_ID { 0x9E, 0x00, 0x00, 0x9E }

LOG_MODULE(fpga);

uint32_t fpga_device_id()
{
    HAL_StatusTypeDef rc;
    struct peripherals *p = get_peripherals();
    uint8_t tx[] = READ_DEIVCE_ID;
    uint8_t rx[4];
    uint32_t id = 0;

    HAL_GPIO_WritePin(GPIO_SPI_CS_PORT, GPIO_SPI_CS_PIN, GPIO_PIN_RESET);
    if ((rc = HAL_SPI_TransmitReceive(&p->hspi, tx, rx, sizeof(tx), SPI_TIMEOUT)) != HAL_OK) {
        LOG_ERR("failed to get device id: %d", rc);
        goto out;
    }

out:
    HAL_GPIO_WritePin(GPIO_SPI_CS_PORT, GPIO_SPI_CS_PIN, GPIO_PIN_SET);
    return id;
}
