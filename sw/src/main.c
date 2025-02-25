#include "fpga_mgmt.h"
#include <zephyr/drivers/gpio.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#define LED_NODE DT_ALIAS(led)
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED_NODE, gpios);

LOG_MODULE_REGISTER(main);

int main(void)
{
    int rc;

    if (!gpio_is_ready_dt(&led)) {
        return 0;
    }

    rc = gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);
    if (rc < 0) {
        return 0;
    }

    LOG_INF("Starting demo");

    fpga_mgmt_load(0, NULL, 0);

    for (;;) {
        rc = gpio_pin_toggle_dt(&led);
        if (rc < 0) {
            return 0;
        }
        k_msleep(1000);
    }

    return 0;
}
