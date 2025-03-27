#include <assert.h>
#include <stdio.h>
#include <stm32f4xx.h>
#include <stm32f4xx_hal_conf.h>

// This function is called by assert() macro
void __assert_func(const char *file, int line, const char *func, const char *expr)
{
    printf("Assertion failed %s:%d (%s): %s\n", file, line, func, expr);
    __disable_irq();
    for (;;) {
        __BKPT(0);
    }
}

// This function is called by HAL library in case of assert error
void assert_failed(uint8_t *file, uint32_t line)
{
#ifndef NDEBUG
    __assert_func((const char *)file, line, "HAL function", "assert_failed()");
#endif
}
