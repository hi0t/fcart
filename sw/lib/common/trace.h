#pragma once

#include <stdio.h>

#ifdef ENABLE_TRACE
#define TRACE(...)           \
    do {                     \
        printf(__VA_ARGS__); \
        printf("\n");        \
    } while (0)
#else
#define TRACE(...)
#endif
