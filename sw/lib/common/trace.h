#pragma once

#include <stdio.h>

#ifdef ENABLE_TRACE
#define TRACE printf
#else
#define TRACE(fmt, args...)
#endif
