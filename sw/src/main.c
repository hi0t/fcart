#include <assert.h>
#include <led.h>
#include <log.h>
#include <soc.h>
#include <stdio.h>

LOG_MODULE(main);

int main()
{
    hw_init();

    assert(0);

    for (;;) {
        led_toggle();
        delay_ms(1000);
    }

    return 0;
}
