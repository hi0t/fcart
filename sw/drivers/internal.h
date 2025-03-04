#pragma once

#include <stm32f4xx_hal.h>

struct peripherals {
    DMA_HandleTypeDef hdma_qspi;
    DMA_HandleTypeDef hdma_sdio_tx;
    DMA_HandleTypeDef hdma_sdio_rx;
    QSPI_HandleTypeDef hqspi;
    SD_HandleTypeDef hsdio;
    RTC_HandleTypeDef hrtc;
};

struct peripherals *get_peripherals();
