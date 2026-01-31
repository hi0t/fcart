#include "spi.h"
#include "internal.h"
#include "log.h"
#include <errno.h>

#define SPI_TIMEOUT 100

LOG_MODULE(spi);

void spi_begin()
{
    HAL_GPIO_WritePin(GPIO_SPI_NCS_PORT, GPIO_SPI_NCS_PIN, GPIO_PIN_RESET);
}

void spi_end()
{
    HAL_GPIO_WritePin(GPIO_SPI_NCS_PORT, GPIO_SPI_NCS_PIN, GPIO_PIN_SET);
}

int spi_send(const uint8_t *data, uint16_t size)
{
    HAL_StatusTypeDef rc;
    struct peripherals *p = get_peripherals();

    if ((rc = HAL_SPI_Transmit(&p->hspi, data, size, SPI_TIMEOUT)) != HAL_OK) {
        LOG_ERR("Failed to send SPI data: %d", rc);
        return -EIO;
    }

    return 0;
}

int spi_recv(uint8_t *data, uint16_t size)
{
    HAL_StatusTypeDef rc;
    struct peripherals *p = get_peripherals();

    if ((rc = HAL_SPI_Receive(&p->hspi, data, size, SPI_TIMEOUT)) != HAL_OK) {
        LOG_ERR("Failed to receive SPI data: %d", rc);
        return -EIO;
    }

    return 0;
}
