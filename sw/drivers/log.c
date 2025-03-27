#include "log.h"
#include "soc.h"
#include <stdarg.h>
#include <stdio.h>
#include <stm32f4xx.h>

enum log_level __log_level = DEFAULT_LOG_LEVEL;

static const char *level_str[] = { NULL, "err", "inf", "dbg" };

static void timestamp_print(uint32_t timestamp)
{
    uint32_t seconds;
    uint32_t hours;
    uint32_t mins;

    seconds = timestamp / 1000U;
    hours = seconds / 3600U;
    seconds -= hours * 3600U;
    mins = seconds / 60U;
    seconds -= mins * 60U;
    printf("[%02lu:%02lu:%02lu.%03lu] ", hours, mins, seconds, timestamp % 1000U);
}

void log_print(enum log_level level, const char *source, const char *fmt, ...)
{
    va_list args;
    va_start(args, fmt);

    timestamp_print(uptime_ms());

    printf("<%s> %s: ", level_str[level], source);
    vprintf(fmt, args);

    printf("\n");

    va_end(args);
}

void log_panic()
{
    __disable_irq();
    for (;;) { }
}
