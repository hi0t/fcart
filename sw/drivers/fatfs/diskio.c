#include "diskio.h"
#include "internal.h"
#include "log.h"

LOG_MODULE(diskio);

#define SD_TIMEOUT 10 * 1000U
#define SD_DEFAULT_BLOCK_SIZE 512

static volatile bool transmit;
static bool initialized = false;

static inline bool is_transfer_state()
{
    struct peripherals *p = get_peripherals();
    return HAL_SD_GetCardState(&p->hsdio) == HAL_SD_CARD_TRANSFER;
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
    struct peripherals *p = get_peripherals();
    HAL_StatusTypeDef rc;

    if (HAL_GPIO_ReadPin(GPIO_SD_CD_PORT, GPIO_SD_CD_PIN) == GPIO_PIN_SET) {
        return STA_NOINIT;
    }

    if (initialized) {
        HAL_SD_DeInit(&p->hsdio);
    }

    if ((rc = HAL_SD_Init(&p->hsdio)) != HAL_OK) {
        LOG_ERR("HAL_SD_Init() failed: %d", rc);
        return STA_NOINIT;
    }

    if ((rc = HAL_SD_ConfigWideBusOperation(&p->hsdio, SDIO_BUS_WIDE_4B)) != HAL_OK) {
        LOG_ERR("HAL_SD_ConfigWideBusOperation() failed: %d", rc);
        return STA_NOINIT;
    }
    initialized = true;

    return wait_transfer_state(SD_TIMEOUT) ? 0 : STA_NOINIT;
}

DRESULT disk_read(BYTE pdrv, BYTE *buff, LBA_t sector, UINT count)
{
    UNUSED(pdrv);
    struct peripherals *p = get_peripherals();
    HAL_StatusTypeDef rc;

    if (!wait_transfer_state(SD_TIMEOUT)) {
        LOG_ERR("Timeout waiting for SD transfer state");
        return RES_ERROR;
    }

    transmit = true;
    if ((rc = HAL_SD_ReadBlocks_DMA(&p->hsdio, buff, sector, count)) != HAL_OK) {
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

    uint32_t status = HAL_SD_GetError(&p->hsdio);
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
    struct peripherals *p = get_peripherals();
    HAL_StatusTypeDef rc;

    if (!wait_transfer_state(SD_TIMEOUT)) {
        LOG_ERR("Timeout waiting for SD transfer state");
        return RES_ERROR;
    }

    transmit = true;
    if ((rc = HAL_SD_WriteBlocks_DMA(&p->hsdio, (uint8_t *)buff, sector, count)) != HAL_OK) {
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

    uint32_t status = HAL_SD_GetError(&p->hsdio);
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
    struct peripherals *p = get_peripherals();
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
        HAL_SD_GetCardInfo(&p->hsdio, &ci);
        *(DWORD *)buff = ci.LogBlockNbr;
        return RES_OK;

    // Get the sector size in byte (WORD)
    case GET_SECTOR_SIZE:
        HAL_SD_GetCardInfo(&p->hsdio, &ci);
        *(WORD *)buff = ci.LogBlockSize;
        return RES_OK;
        break;

    // Get erase block size in unit of sector (DWORD)
    case GET_BLOCK_SIZE:
        HAL_SD_GetCardInfo(&p->hsdio, &ci);
        *(DWORD *)buff = ci.LogBlockSize / SD_DEFAULT_BLOCK_SIZE;
        return RES_OK;

    default:
        return RES_PARERR;
    }
}

DWORD get_fattime()
{
    RTC_DateTypeDef date;
    RTC_TimeTypeDef time;
    DWORD attime;
    struct peripherals *p = get_peripherals();

    HAL_RTC_GetDate(&p->hrtc, &date, RTC_FORMAT_BIN);
    HAL_RTC_GetTime(&p->hrtc, &time, RTC_FORMAT_BIN);

    attime = (((DWORD)date.Year + 20) << 25)
        | ((DWORD)date.Month << 21)
        | ((DWORD)date.Date << 16)
        | (WORD)(time.Hours << 11)
        | (WORD)(time.Minutes << 5)
        | (WORD)(time.Seconds >> 1);

    return attime;
}

void HAL_SD_TxCpltCallback(SD_HandleTypeDef *hsd)
{
    UNUSED(hsd);
    transmit = false;
}

void HAL_SD_RxCpltCallback(SD_HandleTypeDef *hsd)
{
    UNUSED(hsd);
    transmit = false;
}

void HAL_SD_ErrorCallback(SD_HandleTypeDef *hsd)
{
    UNUSED(hsd);
    transmit = false;
}
