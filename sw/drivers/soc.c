#include "soc.h"
#include "led.h"
#include <stm32f4xx_hal.h>

void SysTick_Handler(void)
{
    HAL_IncTick();
}

void soc_hw_init()
{
    HAL_Init();
    HAL_SYSTICK_Config(SystemCoreClock / 1000);
    led_init();
}

void soc_delay(uint32_t ms)
{
    HAL_Delay(ms);
}
