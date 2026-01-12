#include <gpio.h>
#include <soc.h>
#include <tusb.h>

static bool is_firmware_present();
static void jump_to_application();

int main()
{
    hw_init();

    if (is_sd_present() && is_firmware_present()) {
        jump_to_application();
        return 0;
    }

    set_blink_interval(1000);

    for (;;) {
        gpio_poll();
        tud_task();
    }

    return 0;
}

// Check if valid firmware is present at APP_ADDRESS
static bool is_firmware_present()
{
    uint32_t msp_value = *(__IO uint32_t *)APP_ADDRESS;

    if (msp_value == 0xFFFFFFFF) {
        return false;
    }
    if ((msp_value & 0x2FF00000) == SRAM1_BASE) {
        return true;
    }
    return false;
}

// Jump to the application located at APP_ADDRESS
static void jump_to_application()
{
    uint32_t app_stack = *(__IO uint32_t *)APP_ADDRESS;
    uint32_t app_reset = *(__IO uint32_t *)(APP_ADDRESS + 4);

    typedef void (*pFunction)(void);
    pFunction app_entry = (pFunction)app_reset;

    HAL_RCC_DeInit();
    HAL_DeInit();
    SysTick->CTRL = 0;
    SysTick->LOAD = 0;
    SysTick->VAL = 0;
    // Automatically set vector table offset to application start address
    SCB->VTOR = APP_ADDRESS;

    __set_MSP(app_stack);
    app_entry();
}
