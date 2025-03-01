#include <led.h>
#include <soc.h>

int main()
{
    soc_hw_init();

    for (;;) {
        led_toggle();
        soc_delay(1000);
    }

    return 0;
}
