#include "soc.h"
#include "internal.h"
#include "log.h"
#include <errno.h>

LOG_MODULE(soc);

static struct peripherals dev;

static void system_clock_init();
static void periph_clock_init();
static void gpio_init();
static void dma_init();
static void sdio_init();
static void rtc_init();
static void spi_init(SPI_HandleTypeDef *hspi, SPI_TypeDef *inst);

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
    periph_clock_init();
    gpio_init();
    dma_init();
    sdio_init();
    rtc_init();
    spi_init(&dev.hspi1, SPI1);
    //  spi_init(&dev.hspi2, SPI2);

    spi_init_callbacks(&dev.hspi1);
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

    __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

    RCC_OscInitTypeDef hse = {
        .OscillatorType = RCC_OSCILLATORTYPE_HSE,
        .HSEState = RCC_HSE_ON,
        .PLL = {
            .PLLState = RCC_PLL_ON,
            .PLLSource = RCC_PLLSOURCE_HSE,
            .PLLM = RCC_PLL_DIVM,
            .PLLN = 100,
            .PLLP = RCC_PLLP_DIV2,
            .PLLQ = 4,
            .PLLR = 2,
        }
    };
    if ((rc = HAL_RCC_OscConfig(&hse)) != HAL_OK) {
        LOG_ERR("HAL_RCC_OscConfig() failed: %d", rc);
        LOG_PANIC();
    }

    RCC_OscInitTypeDef low = {
        .OscillatorType = RCC_OSCILLATORTYPE_LSE,
        .LSEState = RCC_LSE_ON,
    };
    if ((rc = HAL_RCC_OscConfig(&low)) != HAL_OK) {
        LOG_ERR("lse init failed: %d", rc);
        dev.lse_ready = false;

        low.OscillatorType = RCC_OSCILLATORTYPE_LSI;
        low.LSIState = RCC_LSI_ON;
        if ((rc = HAL_RCC_OscConfig(&low)) != HAL_OK) {
            LOG_ERR("lsi init failed: %d", rc);
            LOG_PANIC();
        }
    } else {
        dev.lse_ready = true;
    }

    RCC_ClkInitTypeDef clk = {
        .ClockType = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK
            | RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2,
        .SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK,
        .AHBCLKDivider = RCC_SYSCLK_DIV1,
        .APB1CLKDivider = RCC_HCLK_DIV2,
        .APB2CLKDivider = RCC_HCLK_DIV1,
    };
    if ((rc = HAL_RCC_ClockConfig(&clk, FLASH_LATENCY_3)) != HAL_OK) {
        LOG_ERR("HAL_RCC_ClockConfig() failed: %d", rc);
        LOG_PANIC();
    }

    HAL_RCC_MCOConfig(RCC_MCO1, RCC_MCO1SOURCE_PLLCLK, RCC_MCODIV_2);
}

static void periph_clock_init()
{
    HAL_StatusTypeDef rc;

    RCC_PeriphCLKInitTypeDef clk = {
        .PeriphClockSelection = RCC_PERIPHCLK_PLLI2S | RCC_PERIPHCLK_CLK48
            | RCC_PERIPHCLK_SDIO,
        .PLLI2S = {
            .PLLI2SM = RCC_PLL_DIVM,
            .PLLI2SN = 192,
            .PLLI2SQ = 8,
            .PLLI2SR = 2,
        },
        .SdioClockSelection = RCC_SDIOCLKSOURCE_CLK48,
        .Clk48ClockSelection = RCC_CLK48CLKSOURCE_PLLI2SQ,
        .PLLI2SSelection = RCC_PLLI2SCLKSOURCE_PLLSRC,
    };
    if ((rc = HAL_RCCEx_PeriphCLKConfig(&clk)) != HAL_OK) {
        LOG_ERR("HAL_RCCEx_PeriphCLKConfig() failed: %d", rc);
        LOG_PANIC();
    }
}

static void gpio_init()
{
    GPIO_InitTypeDef gpio = { 0 };

    gpio.Pin = GPIO_LED_PIN;
    gpio.Mode = GPIO_MODE_OUTPUT_PP;
    gpio.Pull = GPIO_NOPULL;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIO_LED_PORT, &gpio);

    gpio.Pin = GPIO_BTN_PIN;
    gpio.Mode = GPIO_MODE_INPUT;
    gpio.Pull = GPIO_NOPULL;
    HAL_GPIO_Init(GPIO_BTN_PORT, &gpio);

    gpio.Pin = GPIO_SD_CD_PIN;
    gpio.Mode = GPIO_MODE_INPUT;
    gpio.Pull = GPIO_PULLUP;
    HAL_GPIO_Init(GPIO_SD_CD_PORT, &gpio);

    gpio.Pin = GPIO_SPI_CS_PIN;
    gpio.Mode = GPIO_MODE_OUTPUT_OD;
    gpio.Pull = GPIO_NOPULL;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_WritePin(GPIO_SPI_CS_PORT, GPIO_SPI_CS_PIN, GPIO_PIN_SET);
    HAL_GPIO_Init(GPIO_SPI_CS_PORT, &gpio);
}

static void dma_init()
{
    __HAL_RCC_DMA2_CLK_ENABLE();
    HAL_NVIC_SetPriority(DMA2_Stream0_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(DMA2_Stream0_IRQn);

    HAL_NVIC_SetPriority(DMA2_Stream2_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(DMA2_Stream2_IRQn);

    HAL_NVIC_SetPriority(DMA2_Stream3_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(DMA2_Stream3_IRQn);

    HAL_NVIC_SetPriority(DMA2_Stream6_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(DMA2_Stream6_IRQn);
}

static void sdio_init()
{
    dev.hsdio.Instance = SDIO;
    dev.hsdio.Init.ClockEdge = SDIO_CLOCK_EDGE_RISING;
    dev.hsdio.Init.ClockBypass = SDIO_CLOCK_BYPASS_DISABLE;
    dev.hsdio.Init.ClockPowerSave = SDIO_CLOCK_POWER_SAVE_DISABLE;
    dev.hsdio.Init.BusWide = SDIO_BUS_WIDE_1B;
    dev.hsdio.Init.HardwareFlowControl = SDIO_HARDWARE_FLOW_CONTROL_DISABLE;
    dev.hsdio.Init.ClockDiv = 0; // SDIO_CLK = SDIO_MUX / (ClockDiv + 2)
}

static void rtc_init()
{
    HAL_StatusTypeDef rc;

    dev.hrtc.Instance = RTC;
    dev.hrtc.Init.HourFormat = RTC_HOURFORMAT_24;
    dev.hrtc.Init.AsynchPrediv = 127;
    dev.hrtc.Init.SynchPrediv = 255;
    dev.hrtc.Init.OutPut = RTC_OUTPUT_DISABLE;
    dev.hrtc.Init.OutPutPolarity = RTC_OUTPUT_POLARITY_HIGH;
    dev.hrtc.Init.OutPutType = RTC_OUTPUT_TYPE_OPENDRAIN;
    if ((rc = HAL_RTC_Init(&dev.hrtc)) != HAL_OK) {
        LOG_ERR("HAL_RTC_Init() failed: %d", rc);
        LOG_PANIC();
    }
}

static void spi_init(SPI_HandleTypeDef *hspi, SPI_TypeDef *inst)
{
    HAL_StatusTypeDef rc;

    hspi->Instance = inst;
    hspi->Init.Mode = SPI_MODE_MASTER;
    hspi->Init.Direction = SPI_DIRECTION_2LINES;
    hspi->Init.DataSize = SPI_DATASIZE_8BIT;
    hspi->Init.CLKPolarity = SPI_POLARITY_LOW;
    hspi->Init.CLKPhase = SPI_PHASE_1EDGE;
    hspi->Init.NSS = SPI_NSS_SOFT;
    hspi->Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_2;
    hspi->Init.FirstBit = SPI_FIRSTBIT_MSB;
    hspi->Init.TIMode = SPI_TIMODE_DISABLE;
    hspi->Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
    hspi->Init.CRCPolynomial = 10;
    if ((rc = HAL_SPI_Init(hspi)) != HAL_OK) {
        LOG_ERR("HAL_SPI_Init() failed: %d", rc);
        LOG_PANIC();
    }
}

struct peripherals *get_peripherals()
{
    return &dev;
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
