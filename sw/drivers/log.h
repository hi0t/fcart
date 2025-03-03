#pragma once

#include <stdint.h>

enum log_level {
    LOG_LEVEL_NONE = 0,
    LOG_LEVEL_ERR,
    LOG_LEVEL_INF,
    LOG_LEVEL_DBG,
};

#define LOG_ERR(...) LOG_PRINT(LOG_LEVEL_ERR, __VA_ARGS__)
#define LOG_INF(...) LOG_PRINT(LOG_LEVEL_INF, __VA_ARGS__)
#define LOG_DBG(...) LOG_PRINT(LOG_LEVEL_DBG, __VA_ARGS__)
#define LOG_PANIC() log_panic()

#define LOG_MODULE(source)                              \
    static const char *__log_source __unused = #source; \
    extern enum log_level __log_level

#define LOG_PRINT(level, ...) (level <= __log_level ? log_print(level, __log_source, __VA_ARGS__) : (void)0)

void log_print(enum log_level level, const char *source, const char *fmt, ...);
void log_panic();
