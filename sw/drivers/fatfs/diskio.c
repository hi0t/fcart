#include "diskio.h"
#include "log.h"
#include <stdbool.h>
#include <stm32f4xx_hal.h>

LOG_MODULE(diskio);

#define SD_TIMEOUT 5 * 1000
#define SD_DEFAULT_BLOCK_SIZE 512

extern SD_HandleTypeDef _handler_sd;
static volatile bool transmit;

static inline bool is_transfer_state()
{
    return HAL_SD_GetCardState(&_handler_sd) == HAL_SD_CARD_TRANSFER;
}

static bool wait_transfer_state(uint32_t timeout)
{
    uint32_t start = HAL_GetTick();
    while (!is_transfer_state()) {
        if (HAL_GetTick() - start > timeout) {
            return false;
        }
    }
    return true;
}

DSTATUS disk_status(BYTE pdrv)
{
    UNUSED(pdrv);
    return is_transfer_state() ? 0 : STA_NOINIT;
}

DSTATUS disk_initialize(BYTE pdrv)
{
    UNUSED(pdrv);
    HAL_StatusTypeDef rc;

    if (HAL_GPIO_ReadPin(GPIO_SD_CD_PORT, GPIO_SD_CD_PIN) == GPIO_PIN_RESET) {
        return STA_NODISK;
    }

    if ((rc = HAL_SD_Init(&_handler_sd)) != HAL_OK) {
        LOG_ERR("HAL_SD_Init() failed: %d", rc);
        return STA_NOINIT;
    }

    if ((rc = HAL_SD_ConfigWideBusOperation(&_handler_sd, SDIO_BUS_WIDE_4B)) != HAL_OK) {
        LOG_ERR("HAL_SD_ConfigWideBusOperation() failed: %d", rc);
        return STA_NOINIT;
    }

    return is_transfer_state() ? 0 : STA_NOINIT;
}

DRESULT disk_read(BYTE pdrv, BYTE *buff, LBA_t sector, UINT count)
{
    UNUSED(pdrv);
    HAL_StatusTypeDef rc;

    if (!wait_transfer_state(SD_TIMEOUT)) {
        LOG_ERR("Timeout waiting for SD transfer state");
        return RES_ERROR;
    }

    transmit = true;
    if ((rc = HAL_SD_ReadBlocks_DMA(&_handler_sd, buff, sector, count)) != HAL_OK) {
        LOG_ERR("SD start read failed: %d", rc);
        return RES_ERROR;
    }

    // wait until the read operation is finished
    uint32_t start = HAL_GetTick();
    while (transmit) {
        if (HAL_GetTick() - start > SD_TIMEOUT) {
            LOG_ERR("Timeout waiting for SD read completion");
            return RES_ERROR;
        }
    }

    uint32_t status = HAL_SD_GetError(&_handler_sd);
    if (status != SDMMC_ERROR_NONE) {
        LOG_ERR("SD read error: 0x%X", status);
        return RES_ERROR;
    }

    if (!wait_transfer_state(SD_TIMEOUT)) {
        LOG_ERR("Timeout waiting for SD transfer state");
        return RES_ERROR;
    }

    return RES_OK;
}

DRESULT disk_write(BYTE pdrv, const BYTE *buff, LBA_t sector, UINT count)
{
    UNUSED(pdrv);
    HAL_StatusTypeDef rc;

    if (!wait_transfer_state(SD_TIMEOUT)) {
        LOG_ERR("Timeout waiting for SD transfer state");
        return RES_ERROR;
    }

    transmit = true;
    if ((rc = HAL_SD_WriteBlocks_DMA(&_handler_sd, (uint8_t *)buff, sector, count)) != HAL_OK) {
        LOG_ERR("SD start write failed: %d", rc);
        return RES_ERROR;
    }

    // wait until the write operation is finished
    uint32_t start = HAL_GetTick();
    while (transmit) {
        if (HAL_GetTick() - start > SD_TIMEOUT) {
            LOG_ERR("Timeout waiting for SD write completion");
            return RES_ERROR;
        }
    }

    uint32_t status = HAL_SD_GetError(&_handler_sd);
    if (status != SDMMC_ERROR_NONE) {
        LOG_ERR("SD write error: 0x%X", status);
        return RES_ERROR;
    }

    if (!wait_transfer_state(SD_TIMEOUT)) {
        LOG_ERR("Timeout waiting for SD transfer state");
        return RES_ERROR;
    }

    return RES_OK;
}

DRESULT disk_ioctl(BYTE pdrv, BYTE cmd, void *buff)
{
    UNUSED(pdrv);
    HAL_SD_CardInfoTypeDef ci;

    if (!is_transfer_state()) {
        return RES_NOTRDY;
    }

    switch (cmd) {
    // Make sure that no pending write process
    case CTRL_SYNC:
        return RES_OK;

    // Get number of sectors on the disk (DWORD)
    case GET_SECTOR_COUNT:
        HAL_SD_GetCardInfo(&_handler_sd, &ci);
        *(DWORD *)buff = ci.LogBlockNbr;
        return RES_OK;

    // Get the sector size in byte (WORD)
    case GET_SECTOR_SIZE:
        HAL_SD_GetCardInfo(&_handler_sd, &ci);
        *(WORD *)buff = ci.LogBlockSize;
        return RES_OK;
        break;

    // Get erase block size in unit of sector (DWORD)
    case GET_BLOCK_SIZE:
        HAL_SD_GetCardInfo(&_handler_sd, &ci);
        *(DWORD *)buff = ci.LogBlockSize / SD_DEFAULT_BLOCK_SIZE;
        return RES_OK;

    default:
        return RES_PARERR;
    }
}

DWORD get_fattime()
{
    return 0;
}

void HAL_SD_RxCpltCallback(SD_HandleTypeDef *hsd)
{
    UNUSED(hsd);
    transmit = false;
}

void HAL_SD_TxCpltCallback(SD_HandleTypeDef *hsd)
{
    UNUSED(hsd);
    transmit = false;
}

void HAL_SD_ErrorCallback(SD_HandleTypeDef *hsd)
{
    UNUSED(hsd);
    transmit = false;
}
