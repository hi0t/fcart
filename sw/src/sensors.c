#include "sensors.h"
#include <stdio.h>
#include <zephyr/drivers/sensor.h>
#include <zephyr/logging/log.h>

#define VBAT_SENSOR DT_ALIAS(vbat_sensor)
static const struct device *const vbat_sensor = DEVICE_DT_GET(VBAT_SENSOR);

LOG_MODULE_REGISTER(sensors);

const char *sensor_vbat()
{
    struct sensor_value val;
    int rc;
    static char res[20] = { 0 };

    /* fetch sensor samples */
    rc = sensor_sample_fetch(vbat_sensor);
    if (rc) {
        LOG_ERR("Failed to fetch sample (%d)", rc);
        return res;
    }

    rc = sensor_channel_get(vbat_sensor, SENSOR_CHAN_VOLTAGE, &val);
    if (rc) {
        LOG_ERR("Failed to get data (%d)", rc);
        return res;
    }

    sprintf(res, "%d.%d", val.val1, val.val2 / 1000);
    return res;
}
