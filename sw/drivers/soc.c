#include "soc.h"
#include "internal.h"
#include "log.h"
#include <errno.h>

LOG_MODULE(soc);

static struct peripherals devs;

static void system_clock_init();
static void gpio_init();
static void dma_init();
static void sdio_init();
static void rtc_init();

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
    rtc_init();
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
    RCC_OscInitTypeDef osc = {
        .OscillatorType = RCC_OSCILLATORTYPE_HSE | RCC_OSCILLATORTYPE_LSE,
        .HSEState = RCC_HSE_ON,
        .LSEState = RCC_LSE_ON,
        .PLL.PLLState = RCC_PLL_ON,
        .PLL.PLLSource = RCC_PLLSOURCE_HSE,
        .PLL.PLLM = RCC_PLL_DIVM,
        .PLL.PLLN = 100,
        .PLL.PLLP = RCC_PLLP_DIV2,
        .PLL.PLLQ = 4,
        .PLL.PLLR = 2,
    };
    RCC_ClkInitTypeDef clk = {
        .ClockType = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK
            | RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2,
        .SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK,
        .AHBCLKDivider = RCC_SYSCLK_DIV1,
        .APB1CLKDivider = RCC_HCLK_DIV2,
        .APB2CLKDivider = RCC_HCLK_DIV1,
    };

    __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

    if ((rc = HAL_RCC_OscConfig(&osc)) != HAL_OK) {
        LOG_ERR("HAL_RCC_OscConfig() failed: %d", rc);
        LOG_PANIC();
    }

    if ((rc = HAL_RCC_ClockConfig(&clk, FLASH_LATENCY_3)) != HAL_OK) {
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
    devs.hsdio.Instance = SDIO;
    devs.hsdio.Init.ClockEdge = SDIO_CLOCK_EDGE_RISING;
    devs.hsdio.Init.ClockBypass = SDIO_CLOCK_BYPASS_DISABLE;
    devs.hsdio.Init.ClockPowerSave = SDIO_CLOCK_POWER_SAVE_DISABLE;
    devs.hsdio.Init.BusWide = SDIO_BUS_WIDE_1B;
    devs.hsdio.Init.HardwareFlowControl = SDIO_HARDWARE_FLOW_CONTROL_DISABLE;
    devs.hsdio.Init.ClockDiv = 0;
}

static void rtc_init()
{
    HAL_StatusTypeDef rc;

    devs.hrtc.Instance = RTC;
    devs.hrtc.Init.HourFormat = RTC_HOURFORMAT_24;
    devs.hrtc.Init.AsynchPrediv = 127;
    devs.hrtc.Init.SynchPrediv = 255;
    devs.hrtc.Init.OutPut = RTC_OUTPUT_DISABLE;
    devs.hrtc.Init.OutPutPolarity = RTC_OUTPUT_POLARITY_HIGH;
    devs.hrtc.Init.OutPutType = RTC_OUTPUT_TYPE_OPENDRAIN;
    if ((rc = HAL_RTC_Init(&devs.hrtc)) != HAL_OK) {
        LOG_ERR("HAL_RTC_Init() failed: %d", rc);
        LOG_PANIC();
    }
}

struct peripherals *get_peripherals()
{
    return &devs;
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
