#include "soc.h"
#include "internal.h"
#include "log.h"
#include <errno.h>
#include <tusb.h>

LOG_MODULE(soc);

static struct peripherals dev;

static void system_clock_init();
static void gpio_init();
static void dma_init();
static void qspi_init();
static void sdio_init();
static void rtc_init();
static void spi_init();
static void tim6_init();
static void usb_init();

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
    qspi_init();
#ifdef ENABLE_SD_FS
    sdio_init();
#endif
    rtc_init();
    spi_init();
    tim6_init();
    usb_init();

    HAL_TIM_Base_Start(&dev.htim6);

    tusb_rhport_init_t dev_init = { .role = TUSB_ROLE_DEVICE, .speed = TUSB_SPEED_AUTO };
    tusb_init(BOARD_TUD_RHPORT, &dev_init);
}

void delay_us(uint16_t us)
{
    __HAL_TIM_SET_COUNTER(&dev.htim6, 0);
    while (__HAL_TIM_GET_COUNTER(&dev.htim6) < us)
        ;
}

void delay_ms(uint16_t ms)
{
    while (ms > 0) {
        __HAL_TIM_SET_COUNTER(&dev.htim6, 0);
        ms--;
        while (__HAL_TIM_GET_COUNTER(&dev.htim6) < 1000)
            ;
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
            .PLLN = 96,
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

    gpio.Pin = GPIO_IRQ_PIN;
    gpio.Mode = GPIO_MODE_INPUT;
    gpio.Pull = GPIO_NOPULL;
    HAL_GPIO_Init(GPIO_IRQ_PORT, &gpio);

    gpio.Pin = GPIO_SD_CD_PIN;
    gpio.Mode = GPIO_MODE_INPUT;
    gpio.Pull = GPIO_PULLUP;
    HAL_GPIO_Init(GPIO_SD_CD_PORT, &gpio);
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

    HAL_NVIC_SetPriority(DMA2_Stream7_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(DMA2_Stream7_IRQn);
}

static void qspi_init()
{
    HAL_StatusTypeDef rc;

    dev.hqspi.Instance = QUADSPI;
    dev.hqspi.Init.ClockPrescaler = 7; // QSPI_CLK = HCLK / (Prescaler + 1)
    dev.hqspi.Init.FifoThreshold = 1;
    dev.hqspi.Init.SampleShifting = QSPI_SAMPLE_SHIFTING_NONE;
    dev.hqspi.Init.FlashSize = 22; // 2^(FlashSize+1) bytes
    dev.hqspi.Init.ChipSelectHighTime = QSPI_CS_HIGH_TIME_1_CYCLE;
    dev.hqspi.Init.ClockMode = QSPI_CLOCK_MODE_0;
    dev.hqspi.Init.FlashID = QSPI_FLASH_ID_1;
    dev.hqspi.Init.DualFlash = QSPI_DUALFLASH_DISABLE;
    if ((rc = HAL_QSPI_Init(&dev.hqspi)) != HAL_OK) {
        LOG_ERR("HAL_QSPI_Init() failed: %d", rc);
        LOG_PANIC();
    }
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

static void spi_init()
{
    HAL_StatusTypeDef rc;

    dev.hspi.Instance = SPI1;
    dev.hspi.Init.Mode = SPI_MODE_MASTER;
    dev.hspi.Init.Direction = SPI_DIRECTION_2LINES;
    dev.hspi.Init.DataSize = SPI_DATASIZE_8BIT;
    dev.hspi.Init.CLKPolarity = SPI_POLARITY_LOW;
    dev.hspi.Init.CLKPhase = SPI_PHASE_1EDGE;
    dev.hspi.Init.NSS = SPI_NSS_SOFT;
    dev.hspi.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_2;
    dev.hspi.Init.FirstBit = SPI_FIRSTBIT_MSB;
    dev.hspi.Init.TIMode = SPI_TIMODE_DISABLE;
    dev.hspi.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
    dev.hspi.Init.CRCPolynomial = 10;
    if ((rc = HAL_SPI_Init(&dev.hspi)) != HAL_OK) {
        LOG_ERR("HAL_SPI_Init() failed: %d", rc);
        LOG_PANIC();
    }
}

static void tim6_init()
{
    HAL_StatusTypeDef rc;

    uint32_t ticks = (HAL_RCC_GetHCLKFreq() / 1000000U);

    dev.htim6.Instance = TIM6;
    dev.htim6.Init.Prescaler = ticks - 1;
    dev.htim6.Init.CounterMode = TIM_COUNTERMODE_UP;
    dev.htim6.Init.Period = 65535;
    dev.htim6.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
    if ((rc = HAL_TIM_Base_Init(&dev.htim6)) != HAL_OK) {
        LOG_ERR("HAL_TIM_Base_Init() failed: %d", rc);
        LOG_PANIC();
    }

    TIM_MasterConfigTypeDef master = {
        .MasterOutputTrigger = TIM_TRGO_RESET,
        .MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE,
    };
    if ((rc = HAL_TIMEx_MasterConfigSynchronization(&dev.htim6, &master)) != HAL_OK) {
        LOG_ERR("HAL_TIMEx_MasterConfigSynchronization() failed: %d", rc);
        LOG_PANIC();
    }
}

static void usb_init()
{
    HAL_StatusTypeDef rc;
    GPIO_InitTypeDef gpio = {
        .Pin = GPIO_PIN_11 | GPIO_PIN_12,
        .Mode = GPIO_MODE_AF_PP,
        .Pull = GPIO_NOPULL,
        .Speed = GPIO_SPEED_FREQ_VERY_HIGH,
        .Alternate = GPIO_AF10_OTG_FS,
    };
    RCC_PeriphCLKInitTypeDef clk = {
        .PeriphClockSelection = RCC_PERIPHCLK_CLK48,
        .Clk48ClockSelection = RCC_CLK48CLKSOURCE_PLLQ,
    };

// VBUS Sensing setup
#ifdef ENABLE_USB_VBUS_SENSING
    // Enable HW VBUS sensing
    USB_OTG_FS->GCCFG |= USB_OTG_GCCFG_VBDEN;
#else
    // Deactivate VBUS Sensing B
    USB_OTG_FS->GCCFG &= ~USB_OTG_GCCFG_VBDEN;

    // B-peripheral session valid override enable
    USB_OTG_FS->GOTGCTL |= USB_OTG_GOTGCTL_BVALOEN;
    USB_OTG_FS->GOTGCTL |= USB_OTG_GOTGCTL_BVALOVAL;
#endif

    if ((rc = HAL_RCCEx_PeriphCLKConfig(&clk)) != HAL_OK) {
        LOG_ERR("HAL_RCCEx_PeriphCLKConfig() failed: %d", rc);
        LOG_PANIC();
    }

    HAL_GPIO_Init(GPIOA, &gpio);

    __HAL_RCC_USB_OTG_FS_CLK_ENABLE();
    HAL_NVIC_SetPriority(OTG_FS_IRQn, 0, 0);
    HAL_NVIC_EnableIRQ(OTG_FS_IRQn);
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
