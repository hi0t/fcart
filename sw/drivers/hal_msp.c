#include "internal.h"
#include "log.h"

LOG_MODULE(hal_msp);

void HAL_MspInit()
{
    __HAL_RCC_SYSCFG_CLK_ENABLE();
    __HAL_RCC_PWR_CLK_ENABLE();

#ifdef GPIOA_CLK_ENABLE
    __HAL_RCC_GPIOA_CLK_ENABLE();
#endif
#ifdef GPIOB_CLK_ENABLE
    __HAL_RCC_GPIOB_CLK_ENABLE();
#endif
#ifdef GPIOC_CLK_ENABLE
    __HAL_RCC_GPIOC_CLK_ENABLE();
#endif
#ifdef GPIOD_CLK_ENABLE
    __HAL_RCC_GPIOD_CLK_ENABLE();
#endif
}

void HAL_QSPI_MspInit(QSPI_HandleTypeDef *hqspi)
{
    HAL_StatusTypeDef rc;
    GPIO_InitTypeDef gpio = {
        .Mode = GPIO_MODE_AF_PP,
        .Pull = GPIO_NOPULL,
        .Speed = GPIO_SPEED_FREQ_VERY_HIGH,
    };

    if (hqspi->Instance != QUADSPI) {
        return;
    }

    __HAL_RCC_QSPI_CLK_ENABLE();

    gpio.Alternate = GPIO_AF9_QSPI;
    gpio.Pin = GPIO_QSPI_IO0_PIN;
    HAL_GPIO_Init(GPIO_QSPI_IO0_PORT, &gpio);
    gpio.Pin = GPIO_QSPI_IO1_PIN;
    HAL_GPIO_Init(GPIO_QSPI_IO1_PORT, &gpio);
    gpio.Pin = GPIO_QSPI_IO2_PIN;
    HAL_GPIO_Init(GPIO_QSPI_IO2_PORT, &gpio);
    gpio.Pin = GPIO_QSPI_IO3_PIN;
    HAL_GPIO_Init(GPIO_QSPI_IO3_PORT, &gpio);
    gpio.Pin = GPIO_QSPI_CLK_PIN;
    HAL_GPIO_Init(GPIO_QSPI_CLK_PORT, &gpio);
    gpio.Pull = GPIO_PULLUP;
    gpio.Pin = GPIO_QSPI_NCS_PIN;
    HAL_GPIO_Init(GPIO_QSPI_NCS_PORT, &gpio);

    struct peripherals *p = get_peripherals();
    p->hdma_qspi.Instance = DMA2_Stream7;
    p->hdma_qspi.Init.Channel = DMA_CHANNEL_3;
    p->hdma_qspi.Init.Direction = DMA_PERIPH_TO_MEMORY;
    p->hdma_qspi.Init.PeriphInc = DMA_PINC_DISABLE;
    p->hdma_qspi.Init.MemInc = DMA_MINC_ENABLE;
    p->hdma_qspi.Init.PeriphDataAlignment = DMA_PDATAALIGN_BYTE;
    p->hdma_qspi.Init.MemDataAlignment = DMA_MDATAALIGN_BYTE;
    p->hdma_qspi.Init.Mode = DMA_NORMAL;
    p->hdma_qspi.Init.Priority = DMA_PRIORITY_LOW;
    p->hdma_qspi.Init.FIFOMode = DMA_FIFOMODE_DISABLE;
    if ((rc = HAL_DMA_Init(&p->hdma_qspi)) != HAL_OK) {
        LOG_ERR("HAL_DMA_Init() failed: %d", rc);
        LOG_PANIC();
    }
    __HAL_LINKDMA(hqspi, hdma, p->hdma_qspi);

    HAL_NVIC_SetPriority(QUADSPI_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(QUADSPI_IRQn);
}

void HAL_SD_MspInit(SD_HandleTypeDef *hsd)
{
    HAL_StatusTypeDef rc;
    GPIO_InitTypeDef gpio = {
        .Mode = GPIO_MODE_AF_PP,
        .Pull = GPIO_PULLUP,
        .Speed = GPIO_SPEED_FREQ_VERY_HIGH,
        .Alternate = GPIO_AF12_SDIO,
    };
    RCC_PeriphCLKInitTypeDef clk = {
        .PeriphClockSelection = RCC_PERIPHCLK_SDIO | RCC_PERIPHCLK_CLK48,
        .SdioClockSelection = RCC_SDIOCLKSOURCE_CLK48,
        .Clk48ClockSelection = RCC_CLK48CLKSOURCE_PLLQ,
    };

    if (hsd->Instance != SDIO) {
        return;
    }

    if ((rc = HAL_RCCEx_PeriphCLKConfig(&clk)) != HAL_OK) {
        LOG_ERR("HAL_RCCEx_PeriphCLKConfig() failed: %d", rc);
        LOG_PANIC();
    }

    __HAL_RCC_SDIO_CLK_ENABLE();

    gpio.Pin = GPIO_SD_CMD_PIN;
    HAL_GPIO_Init(GPIO_SD_CMD_PORT, &gpio);
    gpio.Pin = GPIO_SD_D0_PIN;
    HAL_GPIO_Init(GPIO_SD_D0_PORT, &gpio);
    gpio.Pin = GPIO_SD_D1_PIN;
    HAL_GPIO_Init(GPIO_SD_D1_PORT, &gpio);
    gpio.Pin = GPIO_SD_D2_PIN;
    HAL_GPIO_Init(GPIO_SD_D2_PORT, &gpio);
    gpio.Pin = GPIO_SD_D3_PIN;
    HAL_GPIO_Init(GPIO_SD_D3_PORT, &gpio);

    gpio.Pull = GPIO_NOPULL,
    gpio.Pin = GPIO_SD_CLK_PIN;
    HAL_GPIO_Init(GPIO_SD_CLK_PORT, &gpio);

    struct peripherals *p = get_peripherals();

    p->hdma_sdio_tx.Instance = DMA2_Stream3;
    p->hdma_sdio_tx.Init.Channel = DMA_CHANNEL_4;
    p->hdma_sdio_tx.Init.Direction = DMA_MEMORY_TO_PERIPH;
    p->hdma_sdio_tx.Init.PeriphInc = DMA_PINC_DISABLE;
    p->hdma_sdio_tx.Init.MemInc = DMA_MINC_ENABLE;
    p->hdma_sdio_tx.Init.PeriphDataAlignment = DMA_PDATAALIGN_WORD;
    p->hdma_sdio_tx.Init.MemDataAlignment = DMA_MDATAALIGN_WORD;
    p->hdma_sdio_tx.Init.Mode = DMA_PFCTRL;
    p->hdma_sdio_tx.Init.Priority = DMA_PRIORITY_LOW;
    p->hdma_sdio_tx.Init.FIFOMode = DMA_FIFOMODE_ENABLE;
    p->hdma_sdio_tx.Init.FIFOThreshold = DMA_FIFO_THRESHOLD_FULL;
    p->hdma_sdio_tx.Init.MemBurst = DMA_MBURST_INC4;
    p->hdma_sdio_tx.Init.PeriphBurst = DMA_PBURST_INC4;
    if ((rc = HAL_DMA_Init(&p->hdma_sdio_tx)) != HAL_OK) {
        LOG_ERR("HAL_DMA_Init() failed: %d", rc);
        LOG_PANIC();
    }
    __HAL_LINKDMA(hsd, hdmatx, p->hdma_sdio_tx);

    p->hdma_sdio_rx.Instance = DMA2_Stream6;
    p->hdma_sdio_rx.Init.Channel = DMA_CHANNEL_4;
    p->hdma_sdio_rx.Init.Direction = DMA_PERIPH_TO_MEMORY;
    p->hdma_sdio_rx.Init.PeriphInc = DMA_PINC_DISABLE;
    p->hdma_sdio_rx.Init.MemInc = DMA_MINC_ENABLE;
    p->hdma_sdio_rx.Init.PeriphDataAlignment = DMA_PDATAALIGN_WORD;
    p->hdma_sdio_rx.Init.MemDataAlignment = DMA_MDATAALIGN_WORD;
    p->hdma_sdio_rx.Init.Mode = DMA_PFCTRL;
    p->hdma_sdio_rx.Init.Priority = DMA_PRIORITY_LOW;
    p->hdma_sdio_rx.Init.FIFOMode = DMA_FIFOMODE_ENABLE;
    p->hdma_sdio_rx.Init.FIFOThreshold = DMA_FIFO_THRESHOLD_FULL;
    p->hdma_sdio_rx.Init.MemBurst = DMA_MBURST_INC4;
    p->hdma_sdio_rx.Init.PeriphBurst = DMA_PBURST_INC4;
    if ((rc = HAL_DMA_Init(&p->hdma_sdio_rx)) != HAL_OK) {
        LOG_ERR("HAL_DMA_Init() failed: %d", rc);
        LOG_PANIC();
    }
    __HAL_LINKDMA(hsd, hdmarx, p->hdma_sdio_rx);

    HAL_NVIC_SetPriority(SDIO_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(SDIO_IRQn);
}

void HAL_RTC_MspInit(RTC_HandleTypeDef *hrtc)
{
    HAL_StatusTypeDef rc;
    struct peripherals *p = get_peripherals();
    RCC_PeriphCLKInitTypeDef clk = {
        .PeriphClockSelection = RCC_PERIPHCLK_RTC,
        .RTCClockSelection = p->lse_ready ? RCC_RTCCLKSOURCE_LSE : RCC_RTCCLKSOURCE_LSI,
    };

    if (hrtc->Instance != RTC) {
        return;
    }

    if ((rc = HAL_RCCEx_PeriphCLKConfig(&clk)) != HAL_OK) {
        LOG_ERR("HAL_RCCEx_PeriphCLKConfig() failed: %d", rc);
        LOG_PANIC();
    }

    __HAL_RCC_RTC_ENABLE();
}

void HAL_SPI_MspInit(SPI_HandleTypeDef *hspi)
{
    HAL_StatusTypeDef rc;
    GPIO_InitTypeDef gpio = {
        .Mode = GPIO_MODE_AF_PP,
        .Pull = GPIO_NOPULL,
        .Speed = GPIO_SPEED_FREQ_VERY_HIGH,
    };

    if (hspi->Instance != SPI1) {
        return;
    }

    gpio.Alternate = GPIO_AF5_SPI1;
    __HAL_RCC_SPI1_CLK_ENABLE();

    gpio.Pin = GPIO_SPI_SCK_PIN;
    HAL_GPIO_Init(GPIO_SPI_SCK_PORT, &gpio);
    gpio.Pin = GPIO_SPI_MISO_PIN;
    HAL_GPIO_Init(GPIO_SPI_MISO_PORT, &gpio);
    gpio.Pin = GPIO_SPI_MOSI_PIN;
    HAL_GPIO_Init(GPIO_SPI_MOSI_PORT, &gpio);

    gpio.Pin = GPIO_SPI_NCS_PIN;
    gpio.Mode = GPIO_MODE_OUTPUT_OD;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_WritePin(GPIO_SPI_NCS_PORT, GPIO_SPI_NCS_PIN, GPIO_PIN_SET);
    HAL_GPIO_Init(GPIO_SPI_NCS_PORT, &gpio);

    struct peripherals *p = get_peripherals();

    // SPI1 TX init
    p->hdma_spi_tx.Instance = DMA2_Stream2;
    p->hdma_spi_tx.Init.Channel = DMA_CHANNEL_2;
    p->hdma_spi_tx.Init.Direction = DMA_MEMORY_TO_PERIPH;
    p->hdma_spi_tx.Init.PeriphInc = DMA_PINC_DISABLE;
    p->hdma_spi_tx.Init.MemInc = DMA_MINC_ENABLE;
    p->hdma_spi_tx.Init.PeriphDataAlignment = DMA_PDATAALIGN_BYTE;
    p->hdma_spi_tx.Init.MemDataAlignment = DMA_MDATAALIGN_BYTE;
    p->hdma_spi_tx.Init.Mode = DMA_NORMAL;
    p->hdma_spi_tx.Init.Priority = DMA_PRIORITY_LOW;
    p->hdma_spi_tx.Init.FIFOMode = DMA_FIFOMODE_DISABLE;
    if ((rc = HAL_DMA_Init(&p->hdma_spi_tx)) != HAL_OK) {
        LOG_ERR("HAL_DMA_Init() failed: %d", rc);
        LOG_PANIC();
    }
    __HAL_LINKDMA(hspi, hdmatx, p->hdma_spi_tx);

    // SPI1 RX init
    p->hdma_spi_rx.Instance = DMA2_Stream0;
    p->hdma_spi_rx.Init.Channel = DMA_CHANNEL_3;
    p->hdma_spi_rx.Init.Direction = DMA_PERIPH_TO_MEMORY;
    p->hdma_spi_rx.Init.PeriphInc = DMA_PINC_DISABLE;
    p->hdma_spi_rx.Init.MemInc = DMA_MINC_ENABLE;
    p->hdma_spi_rx.Init.PeriphDataAlignment = DMA_PDATAALIGN_BYTE;
    p->hdma_spi_rx.Init.MemDataAlignment = DMA_MDATAALIGN_BYTE;
    p->hdma_spi_rx.Init.Mode = DMA_NORMAL;
    p->hdma_spi_rx.Init.Priority = DMA_PRIORITY_LOW;
    p->hdma_spi_rx.Init.FIFOMode = DMA_FIFOMODE_DISABLE;
    if ((rc = HAL_DMA_Init(&p->hdma_spi_rx)) != HAL_OK) {
        LOG_ERR("HAL_DMA_Init() failed: %d", rc);
        LOG_PANIC();
    }
    __HAL_LINKDMA(hspi, hdmarx, p->hdma_spi_rx);

    // SPI1 interrupt init
    HAL_NVIC_SetPriority(SPI1_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(SPI1_IRQn);
}

void HAL_TIM_Base_MspInit(TIM_HandleTypeDef *htim)
{
    if (htim->Instance == TIM6) {
        __HAL_RCC_TIM6_CLK_ENABLE();
    }
}
