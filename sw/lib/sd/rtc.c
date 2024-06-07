#include "hardware/rtc.h"
#include "ff.h"

DWORD get_fattime()
{
    datetime_t t = { 0, 0, 0, 0, 0, 0, 0 };
    if (!rtc_get_datetime(&t)) {
        return 0;
    }
    return (t.year - 1980) << 25 | t.month << 21 | t.day << 16
        | t.hour << 11 | t.min << 5 | t.sec >> 1;
}
