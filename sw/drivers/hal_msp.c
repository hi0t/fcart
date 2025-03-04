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
        .Clk48ClockSelection = RCC_CLK48CLKSOURCE_PLLQ,
        .SdioClockSelection = RCC_SDIOCLKSOURCE_CLK48,
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
    gpio.Pin = GPIO_SD_CK_PIN;
    gpio.Pull = GPIO_NOPULL,
    HAL_GPIO_Init(GPIO_SD_CK_PORT, &gpio);

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
    RCC_PeriphCLKInitTypeDef clk = {
        .PeriphClockSelection = RCC_PERIPHCLK_RTC,
        .RTCClockSelection = RCC_RTCCLKSOURCE_LSE,
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
