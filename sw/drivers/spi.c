#include "spi.h"
#include "internal.h"
#include "log.h"
#include <errno.h>

#define SPI_TIMEOUT 100

static volatile bool transmit;

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

    transmit = true;
    if ((rc = HAL_SPI_Transmit_DMA(&p->hspi, data, size)) != HAL_OK) {
        LOG_ERR("Failed to send SPI data: %d", rc);
        return -EIO;
    }

    uint32_t start = HAL_GetTick();
    while (transmit) {
        if (HAL_GetTick() - start > SPI_TIMEOUT) {
            LOG_ERR("Timeout waiting for SPI transfer completion");
            return -EIO;
        }
    }

    uint32_t status = HAL_SPI_GetError(&p->hspi);
    if (status != HAL_SPI_ERROR_NONE) {
        LOG_ERR("SPI transfer error: 0x%X", status);
        return -EIO;
    }

    return 0;
}

int spi_recv(uint8_t *data, uint16_t size)
{
    HAL_StatusTypeDef rc;
    struct peripherals *p = get_peripherals();

    transmit = true;
    if ((rc = HAL_SPI_Receive_DMA(&p->hspi, data, size)) != HAL_OK) {
        LOG_ERR("Failed to receive SPI data: %d", rc);
        return -EIO;
    }

    uint32_t start = HAL_GetTick();
    while (transmit) {
        if (HAL_GetTick() - start > SPI_TIMEOUT) {
            LOG_ERR("Timeout waiting for SPI transfer completion");
            return -EIO;
        }
    }

    uint32_t status = HAL_SPI_GetError(&p->hspi);
    if (status != HAL_SPI_ERROR_NONE) {
        LOG_ERR("SPI transfer error: 0x%X", status);
        return -EIO;
    }

    return 0;
}

void HAL_SPI_TxCpltCallback(SPI_HandleTypeDef *hspi)
{
    UNUSED(hspi);
    transmit = false;
}

void HAL_SPI_RxCpltCallback(SPI_HandleTypeDef *hspi)
{
    UNUSED(hspi);
    transmit = false;
}

void HAL_SPI_ErrorCallback(SPI_HandleTypeDef *hspi)
{
    UNUSED(hspi);
    transmit = false;
}
