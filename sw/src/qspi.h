#pragma once

#include <errno.h>
#include <zephyr/device.h>

#define FCART_QSPI_NODE DT_NODELABEL(quadspi)

typedef int (*qspi_api_cmd_t)(const struct device *dev, uint8_t cmd, uint8_t *data, size_t size);

__subsystem struct qspi_driver_api {
    qspi_api_cmd_t send;
};

static inline int qspi_send(const struct device *dev, uint8_t cmd, uint8_t *data, size_t size)
{
    const struct qspi_driver_api *api = dev->api;
    return api->send(dev, cmd, data, size);
}
