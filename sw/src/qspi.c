#include "qspi.h"
#include <zephyr/drivers/clock_control/stm32_clock_control.h>
#include <zephyr/drivers/pinctrl.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(qspi);

struct qspi_data {
    QSPI_HandleTypeDef hqspi;
};

struct qspi_config {
    struct stm32_pclken pclken;
    const struct pinctrl_dev_config *pcfg;
};

static int send(const struct device *dev, uint8_t cmd, uint8_t *data, size_t size)
{
    struct qspi_data *dev_data = dev->data;
    HAL_StatusTypeDef hal_rc;

    QSPI_CommandTypeDef cmd_def = {
        .Instruction = cmd,
        .InstructionMode = QSPI_INSTRUCTION_4_LINES,
        .DataMode = QSPI_DATA_4_LINES,
        .NbData = size,
    };

    hal_rc = HAL_QSPI_Command(&dev_data->hqspi, &cmd_def, HAL_QSPI_TIMEOUT_DEFAULT_VALUE);
    if (hal_rc != HAL_OK) {
        LOG_ERR("Failed to send QSPI command (%d)", hal_rc);
        return -EIO;
    }

    if (data != NULL) {
        hal_rc = HAL_QSPI_Transmit(&dev_data->hqspi, data, HAL_QSPI_TIMEOUT_DEFAULT_VALUE);
        if (hal_rc != HAL_OK) {
            LOG_ERR("Failed to write QSPI data (%d)", hal_rc);
            return -EIO;
        }
    }
    return 0;
}

static int qspi_init(const struct device *dev)
{
    struct qspi_data *dev_data = dev->data;
    const struct qspi_config *dev_cfg = dev->config;
    int rc;
    HAL_StatusTypeDef hal_rc;

    rc = pinctrl_apply_state(dev_cfg->pcfg, PINCTRL_STATE_DEFAULT);
    if (rc < 0) {
        LOG_ERR("QSPI pinctrl setup failed (%d)", rc);
        return rc;
    }

    /* Clock configuration */
    if (clock_control_on(DEVICE_DT_GET(STM32_CLOCK_CONTROL_NODE),
            (clock_control_subsys_t)&dev_cfg->pclken)
        != 0) {
        LOG_DBG("Could not enable QSPI clock");
        return -EIO;
    }

    hal_rc = HAL_QSPI_Init(&dev_data->hqspi);
    if (hal_rc != HAL_OK) {
        LOG_ERR("QSPI HAL init failed (%d)", hal_rc);
        return -ENODEV;
    }

#if DT_NODE_HAS_PROP(FCART_QSPI_NODE, flash_id)
    uint8_t qspi_flash_id = DT_PROP(FCART_QSPI_NODE, flash_id);

    HAL_QSPI_SetFlashID(&dev_data->hqspi, (qspi_flash_id - 1) << QUADSPI_CR_FSEL_Pos);
#endif

    return 0;
}

static struct qspi_data qspi_dev_data = {
    .hqspi = {
        .Instance = (QUADSPI_TypeDef *)DT_REG_ADDR(FCART_QSPI_NODE),
        .Init = {
            .ClockPrescaler = 1,
            .FifoThreshold = 4,
            .ChipSelectHighTime = QSPI_CS_HIGH_TIME_1_CYCLE,
            .ClockMode = QSPI_CLOCK_MODE_0,
            .FlashSize = 0xFFFFFFFF,
        },
    },
};

PINCTRL_DT_DEFINE(FCART_QSPI_NODE);

static const struct qspi_config qspi_dev_config = {
    .pclken = {
        .enr = DT_CLOCKS_CELL(FCART_QSPI_NODE, bits),
        .bus = DT_CLOCKS_CELL(FCART_QSPI_NODE, bus),
    },
    .pcfg = PINCTRL_DT_DEV_CONFIG_GET(FCART_QSPI_NODE),
};

static const struct qspi_driver_api qspi_api = {
    .send = send,
};

DEVICE_DT_DEFINE(FCART_QSPI_NODE,
    &qspi_init,
    NULL,
    &qspi_dev_data,
    &qspi_dev_config,
    POST_KERNEL,
    CONFIG_KERNEL_INIT_PRIORITY_DEVICE,
    &qspi_api);
