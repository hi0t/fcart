#include "led.h"
#include <stm32f4xx_hal.h>

#define LED_PORT GPIOB
#define LED_PIN GPIO_PIN_2
#define LED_PORT_CLK_ENABLE __HAL_RCC_GPIOB_CLK_ENABLE

void led_init()
{
    GPIO_InitTypeDef GPIO_Config;

    GPIO_Config.Mode = GPIO_MODE_OUTPUT_PP;
    GPIO_Config.Pull = GPIO_NOPULL;
    GPIO_Config.Speed = GPIO_SPEED_FREQ_HIGH;

    GPIO_Config.Pin = LED_PIN;

    LED_PORT_CLK_ENABLE();
    HAL_GPIO_Init(LED_PORT, &GPIO_Config);
}

void led_toggle()
{
    HAL_GPIO_TogglePin(LED_PORT, LED_PIN);
}
