#pragma once

#include <stdint.h>
#include <sys/cdefs.h>

enum log_level {
    LOG_LEVEL_NONE = 0,
    LOG_LEVEL_ERR,
    LOG_LEVEL_INF,
    LOG_LEVEL_DBG,
};

/**
 * @brief Logs an error message.
 *
 * This macro logs an error message with the specified format and arguments.
 *
 * @param ... The format string and arguments for the error message.
 */
#define LOG_ERR(...) LOG_PRINT(LOG_LEVEL_ERR, __VA_ARGS__)

/**
 * @brief Logs an informational message.
 *
 * This macro logs a message with the informational log level.
 *
 * @param ... The format string and arguments for the log message.
 */
#define LOG_INF(...) LOG_PRINT(LOG_LEVEL_INF, __VA_ARGS__)

/**
 * @brief Macro to log debug messages.
 *
 * This macro logs messages at the debug level.
 *
 * @param ... The format string and arguments for the error message.
 */
#define LOG_DBG(...) LOG_PRINT(LOG_LEVEL_DBG, __VA_ARGS__)

/**
 * @brief Macro to log a panic event.
 *
 * It is used to indicate a critical error that requires immediate attention.
 */
#define LOG_PANIC() log_panic()

/**
 * @brief Macro to define a log module for a given source file.
 *
 * This macro is used to define a log module for a specific source file.
 * It should be placed at the top of the source file to associate the file
 * with a log module, which can then be used for logging purposes.
 *
 * @param source The name of the log module.
 */
#define LOG_MODULE(source)                              \
    static const char *__log_source __unused = #source; \
    extern enum log_level __log_level

#define LOG_PRINT(level, ...) (level <= __log_level ? log_print(level, __log_source, __VA_ARGS__) : (void)0)

void log_print(enum log_level level, const char *source, const char *fmt, ...);
void log_panic();
