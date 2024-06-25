#pragma once

#include "pico/types.h"

#ifdef SDCARD_SPI
void sdcard_init(uint port, uint miso, uint mosi, uint sck, uint cs);
#else
void sdcard_init(uint sck, uint cmd, uint d0);
#endif
