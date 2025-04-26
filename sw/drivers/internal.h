#pragma once

#include <stdbool.h>
#include <stm32f4xx_hal.h>

struct peripherals {
    DMA_HandleTypeDef hdma_sdio_tx;
    DMA_HandleTypeDef hdma_sdio_rx;
    SD_HandleTypeDef hsdio;
    RTC_HandleTypeDef hrtc;
    SPI_HandleTypeDef hspi1;
    SPI_HandleTypeDef hspi2;
    bool lse_ready;
};

struct peripherals *get_peripherals();
