#include "spi.h"
#include "internal.h"
#include "log.h"
#include <errno.h>

#define SPI_TIMEOUT 100

LOG_MODULE(spi);

int spi_transmit_receive(const uint8_t *tx, uint8_t *rx, uint16_t size)
{
    HAL_StatusTypeDef rc;
    int err = 0;
    struct peripherals *p = get_peripherals();

    HAL_GPIO_WritePin(GPIO_SPI_CS_PORT, GPIO_SPI_CS_PIN, GPIO_PIN_RESET);
    if ((rc = HAL_SPI_TransmitReceive(&p->hspi, tx, rx, size, SPI_TIMEOUT)) != HAL_OK) {
        LOG_ERR("failed to get device id: %d", rc);
        err = -EIO;
        goto out;
    }

out:
    HAL_GPIO_WritePin(GPIO_SPI_CS_PORT, GPIO_SPI_CS_PIN, GPIO_PIN_SET);
    return err;
}
