#include "internal.h"
#include <tusb.h>

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

void SysTick_Handler()
{
    HAL_IncTick();
}

void QUADSPI_IRQHandler(void)
{
    struct peripherals *p = get_peripherals();
    HAL_QSPI_IRQHandler(&p->hqspi);
}

#ifdef ENABLE_SD_FS
void SDIO_IRQHandler()
{
    struct peripherals *p = get_peripherals();
    HAL_SD_IRQHandler(&p->hsdio);
}
#endif

void SPI1_IRQHandler()
{
    struct peripherals *p = get_peripherals();
    HAL_SPI_IRQHandler(&p->hspi);
}

void OTG_FS_IRQHandler()
{
    tud_int_handler(0);
}

void DMA2_Stream0_IRQHandler()
{
    struct peripherals *p = get_peripherals();
    HAL_DMA_IRQHandler(&p->hdma_spi_rx);
}

void DMA2_Stream2_IRQHandler()
{
    struct peripherals *p = get_peripherals();
    HAL_DMA_IRQHandler(&p->hdma_spi_tx);
}

void DMA2_Stream3_IRQHandler()
{
    struct peripherals *p = get_peripherals();
    HAL_DMA_IRQHandler(&p->hdma_sdio_tx);
}

void DMA2_Stream6_IRQHandler()
{
    struct peripherals *p = get_peripherals();
    HAL_DMA_IRQHandler(&p->hdma_sdio_rx);
}

void DMA2_Stream7_IRQHandler()
{
    struct peripherals *p = get_peripherals();
    HAL_DMA_IRQHandler(&p->hdma_qspi);
}
