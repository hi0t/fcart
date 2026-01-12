#pragma once

#include <stm32f4xx_hal.h>

struct peripherals {
    DMA_HandleTypeDef hdma_qspi;
    DMA_HandleTypeDef hdma_sdio_tx;
    DMA_HandleTypeDef hdma_sdio_rx;
    DMA_HandleTypeDef hdma_spi_tx;
    DMA_HandleTypeDef hdma_spi_rx;
    QSPI_HandleTypeDef hqspi;
    SD_HandleTypeDef hsdio;
    RTC_HandleTypeDef hrtc;
    SPI_HandleTypeDef hspi;
    TIM_HandleTypeDef htim6;
    PCD_HandleTypeDef hpcd;
    bool lse_ready;
};

struct peripherals *get_peripherals();
