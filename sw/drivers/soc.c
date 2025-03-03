#include "soc.h"
#include "log.h"
#include <errno.h>
#include <stm32f4xx_hal.h>

LOG_MODULE(soc);

DMA_HandleTypeDef _hdma_quadspi;
DMA_HandleTypeDef _hdma_sdio_tx;
DMA_HandleTypeDef _hdma_sdio_rx;
SD_HandleTypeDef _handler_sd;

static void system_clock_init();
static void gpio_init();
static void dma_init();
static void sdio_init();

#ifdef ENABLE_SEMIHOSTING
extern void initialise_monitor_handles();
#endif

void hw_init()
{
#ifdef ENABLE_SEMIHOSTING
    initialise_monitor_handles();
#endif

    HAL_Init();
    system_clock_init();
    gpio_init();
    dma_init();
    sdio_init();
}

void delay_ms(uint32_t ms)
{
    if (ms > 0) {
        // HAL code adds an extra ms inside the HAL_Delay()
        HAL_Delay(ms - 1);
    }
}

uint32_t uptime_ms()
{
    return HAL_GetTick();
}

static void system_clock_init()
{
    HAL_StatusTypeDef rc;
    RCC_OscInitTypeDef RCC_OscInitStruct = { 0 };
    RCC_ClkInitTypeDef RCC_ClkInitStruct = { 0 };

    __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

    RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE | RCC_OSCILLATORTYPE_LSE;
    RCC_OscInitStruct.HSEState = RCC_HSE_ON;
    RCC_OscInitStruct.LSEState = RCC_LSE_ON;
    RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
    RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
    RCC_OscInitStruct.PLL.PLLM = RCC_PLL_DIVM;
    RCC_OscInitStruct.PLL.PLLN = 100;
    RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2;
    RCC_OscInitStruct.PLL.PLLQ = 4;
    RCC_OscInitStruct.PLL.PLLR = 2;
    if ((rc = HAL_RCC_OscConfig(&RCC_OscInitStruct)) != HAL_OK) {
        LOG_ERR("HAL_RCC_OscConfig() failed: %d", rc);
        LOG_PANIC();
    }

    RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK
        | RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2;
    RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
    RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
    RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV2;
    RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

    if ((rc = HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_3)) != HAL_OK) {
        LOG_ERR("HAL_RCC_ClockConfig() failed: %d", rc);
        LOG_PANIC();
    }
    // HAL_RCC_MCOConfig(RCC_MCO1, RCC_MCO1SOURCE_PLLCLK, RCC_MCODIV_2);
}

static void gpio_init()
{
    GPIO_InitTypeDef gpio = { 0 };

    gpio.Mode = GPIO_MODE_OUTPUT_PP;
    gpio.Pull = GPIO_NOPULL;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    gpio.Pin = GPIO_LED_PIN;
    HAL_GPIO_Init(GPIO_LED_PORT, &gpio);

    gpio.Mode = GPIO_MODE_INPUT;
    gpio.Pull = GPIO_PULLUP;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    gpio.Pin = GPIO_SD_CD_PIN;
    HAL_GPIO_Init(GPIO_SD_CD_PORT, &gpio);
}

static void dma_init()
{
    __HAL_RCC_DMA2_CLK_ENABLE();

    HAL_NVIC_SetPriority(DMA2_Stream3_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(DMA2_Stream3_IRQn);

    HAL_NVIC_SetPriority(DMA2_Stream6_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(DMA2_Stream6_IRQn);

    HAL_NVIC_SetPriority(DMA2_Stream7_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(DMA2_Stream7_IRQn);
}

static void sdio_init()
{
    _handler_sd.Instance = SDIO;
    _handler_sd.Init.ClockEdge = SDIO_CLOCK_EDGE_RISING;
    _handler_sd.Init.ClockBypass = SDIO_CLOCK_BYPASS_DISABLE;
    _handler_sd.Init.ClockPowerSave = SDIO_CLOCK_POWER_SAVE_DISABLE;
    _handler_sd.Init.BusWide = SDIO_BUS_WIDE_1B;
    _handler_sd.Init.HardwareFlowControl = SDIO_HARDWARE_FLOW_CONTROL_DISABLE;
    _handler_sd.Init.ClockDiv = 0;
}

static uint8_t *__sbrk_heap_end;
void *_sbrk(ptrdiff_t incr)
{
    extern uint8_t _end;
    extern uint8_t _estack;
    extern uint32_t _Min_Stack_Size;
    const uint32_t stack_limit = (uint32_t)&_estack - (uint32_t)&_Min_Stack_Size;
    const uint8_t *max_heap = (uint8_t *)stack_limit;
    uint8_t *prev_heap_end;

    if (NULL == __sbrk_heap_end) {
        __sbrk_heap_end = &_end;
    }

    if (__sbrk_heap_end + incr > max_heap) {
        errno = ENOMEM;
        return (void *)-1;
    }

    prev_heap_end = __sbrk_heap_end;
    __sbrk_heap_end += incr;

    return (void *)prev_heap_end;
}
