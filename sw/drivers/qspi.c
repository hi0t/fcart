#include "qspi.h"
#include "internal.h"
#include "log.h"
#include <errno.h>

LOG_MODULE(qspi);

static volatile bool transmit;

#define QSPI_TIMEOUT 1000U

int qspi_read(uint8_t cmd, uint32_t address, uint8_t *data, uint32_t size)
{
    struct peripherals *p = get_peripherals();
    QSPI_CommandTypeDef cmdcfg = {
        .Instruction = cmd,
        .Address = address,
        .AddressSize = QSPI_ADDRESS_24_BITS,
        .DummyCycles = 4,
        .InstructionMode = QSPI_INSTRUCTION_4_LINES,
        .AddressMode = QSPI_ADDRESS_4_LINES,
        .NbData = size,
        .DataMode = QSPI_DATA_4_LINES,
    };

    HAL_StatusTypeDef rc;

    if ((rc = HAL_QSPI_Command(&p->hqspi, &cmdcfg, QSPI_TIMEOUT)) != HAL_OK) {
        LOG_ERR("Failed to send OSPI instruction: %d", rc);
        return -EIO;
    }

    if (size > 32) {
        transmit = true;
        if ((rc = HAL_QSPI_Receive_DMA(&p->hqspi, data)) != HAL_OK) {
            LOG_ERR("Failed to receive OSPI data: %d", rc);
            return -EIO;
        }

        // wait until the transfer operation is finished
        uint32_t start = HAL_GetTick();
        while (transmit) {
            if (HAL_GetTick() - start > QSPI_TIMEOUT) {
                LOG_ERR("Timeout waiting for OSPI transfer completion");
                return -EIO;
            }
        }
        uint32_t status = HAL_QSPI_GetError(&p->hqspi);
        if (status != HAL_QSPI_ERROR_NONE) {
            LOG_ERR("OSPI transfer error: 0x%X", status);
            return -EIO;
        }
    } else {
        if ((rc = HAL_QSPI_Receive(&p->hqspi, data, QSPI_TIMEOUT)) != HAL_OK) {
            LOG_ERR("Failed to receive OSPI data: %d", rc);
            return -EIO;
        }
    }
    return 0;
}

int qspi_write(uint8_t cmd, uint32_t address, const uint8_t *data, uint32_t size)
{
    int r = qspi_write_begin(cmd, address, data, size);
    if (r != 0) {
        return r;
    }
    return qspi_write_end();
}

int qspi_write_begin(uint8_t cmd, uint32_t address, const uint8_t *data, uint32_t size)
{
    struct peripherals *p = get_peripherals();
    HAL_StatusTypeDef rc;

    QSPI_CommandTypeDef cmdcfg = {
        .Instruction = cmd,
        .Address = address,
        .AddressSize = QSPI_ADDRESS_24_BITS,
        .InstructionMode = QSPI_INSTRUCTION_4_LINES,
        .AddressMode = QSPI_ADDRESS_4_LINES,
        .NbData = size,
        .DataMode = size > 0 ? QSPI_DATA_4_LINES : QSPI_DATA_NONE,
    };

    if ((rc = HAL_QSPI_Command(&p->hqspi, &cmdcfg, QSPI_TIMEOUT)) != HAL_OK) {
        LOG_ERR("Failed to send OSPI instruction: %d", rc);
        return -EIO;
    }

    transmit = false;
    if (size > 32) {
        transmit = true;
        if ((rc = HAL_QSPI_Transmit_DMA(&p->hqspi, (uint8_t *)data)) != HAL_OK) {
            LOG_ERR("Failed to send OSPI data: %d", rc);
            return -EIO;
        }
    } else if (size > 0) {
        if ((rc = HAL_QSPI_Transmit(&p->hqspi, (uint8_t *)data, QSPI_TIMEOUT)) != HAL_OK) {
            LOG_ERR("Failed to send OSPI data: %d", rc);
            return -EIO;
        }
    }
    return 0;
}

int qspi_write_end()
{
    struct peripherals *p = get_peripherals();

    // wait until the transfer operation is finished
    uint32_t start = HAL_GetTick();
    while (transmit) {
        if (HAL_GetTick() - start > QSPI_TIMEOUT) {
            LOG_ERR("Timeout waiting for OSPI transfer completion");
            return -EIO;
        }
    }

    uint32_t status = HAL_QSPI_GetError(&p->hqspi);
    if (status != HAL_QSPI_ERROR_NONE) {
        LOG_ERR("OSPI transfer error: 0x%X", status);
        return -EIO;
    }
    return 0;
}

void HAL_QSPI_TxCpltCallback(QSPI_HandleTypeDef *hqspi)
{
    UNUSED(hqspi);
    transmit = false;
}

void HAL_QSPI_RxCpltCallback(QSPI_HandleTypeDef *hqspi)
{
    UNUSED(hqspi);
    transmit = false;
}

void HAL_QSPI_ErrorCallback(QSPI_HandleTypeDef *hqspi)
{
    UNUSED(hqspi);
    transmit = false;
}
