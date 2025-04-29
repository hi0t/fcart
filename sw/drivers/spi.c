#include "spi.h"
#include "internal.h"
#include "log.h"
#include <errno.h>

#define SPI_TIMEOUT 100

static volatile bool transmit;
static void spi_callback(SPI_HandleTypeDef *hspi);

LOG_MODULE(spi);

void spi_init_callbacks(SPI_HandleTypeDef *hspi)
{
    HAL_SPI_RegisterCallback(hspi, HAL_SPI_TX_COMPLETE_CB_ID, spi_callback);
    HAL_SPI_RegisterCallback(hspi, HAL_SPI_RX_COMPLETE_CB_ID, spi_callback);
    HAL_SPI_RegisterCallback(hspi, HAL_SPI_ERROR_CB_ID, spi_callback);
}

void spi_begin()
{
    HAL_GPIO_WritePin(GPIO_SPI_CS_PORT, GPIO_SPI_CS_PIN, GPIO_PIN_RESET);
}

void spi_end()
{
    HAL_GPIO_WritePin(GPIO_SPI_CS_PORT, GPIO_SPI_CS_PIN, GPIO_PIN_SET);
}

int spi_send(const uint8_t *data, uint16_t size)
{
    HAL_StatusTypeDef rc;
    struct peripherals *p = get_peripherals();

    transmit = true;
    if ((rc = HAL_SPI_Transmit_DMA(&p->hspi1, data, size)) != HAL_OK) {
        LOG_ERR("failed to get device id: %d", rc);
        return -EIO;
    }

    uint32_t start = HAL_GetTick();
    while (transmit) {
        if (HAL_GetTick() - start > SPI_TIMEOUT) {
            LOG_ERR("Timeout waiting for SPI transfer completion");
            return -EIO;
        }
    }

    uint32_t status = HAL_SPI_GetError(&p->hspi1);
    if (status != HAL_SPI_ERROR_NONE) {
        LOG_ERR("SPI transfer error: 0x%X", status);
        return -EIO;
    }

    return 0;
}

static void spi_callback(SPI_HandleTypeDef *hspi)
{
    UNUSED(hspi);
    transmit = false;
}
