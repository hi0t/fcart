#include <stm32f4xx_hal.h>

extern DMA_HandleTypeDef _hdma_quadspi;
extern DMA_HandleTypeDef _hdma_sdio_tx;
extern DMA_HandleTypeDef _hdma_sdio_rx;
extern SD_HandleTypeDef _handler_sd;

void NMI_Handler()
{
    while (1) {
    }
}

void HardFault_Handler()
{
    while (1) {
    }
}

void MemManage_Handler()
{
    while (1) {
    }
}

void BusFault_Handler()
{
    while (1) {
    }
}

void UsageFault_Handler()
{
    while (1) {
    }
}

void SVC_Handler()
{
}

void DebugMon_Handler()
{
}

void PendSV_Handler()
{
}

void SysTick_Handler(void)
{
    HAL_IncTick();
}

void SDIO_IRQHandler(void)
{
    HAL_SD_IRQHandler(&_handler_sd);
}

void DMA2_Stream3_IRQHandler(void)
{
    HAL_DMA_IRQHandler(&_hdma_sdio_tx);
}

void DMA2_Stream6_IRQHandler(void)
{
    HAL_DMA_IRQHandler(&_hdma_sdio_rx);
}

void DMA2_Stream7_IRQHandler(void)
{
    HAL_DMA_IRQHandler(&_hdma_quadspi);
}
