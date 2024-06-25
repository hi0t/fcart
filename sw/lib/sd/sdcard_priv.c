#include "sdcard_priv.h"

DSTATUS sd_err2ff(sd_err rc)
{
    switch (rc) {
    case SD_ERR_OK:
        return RES_OK;
    case SD_ERR_NO_DEVICE:
    case SD_ERR_NO_RESPONSE:
    case SD_ERR_NO_INIT:
        return RES_NOTRDY;
    case SD_ERR_PARAM:
    case SD_ERR_UNSUPPORTED:
        return RES_PARERR;
    case SD_ERR_WRITE_PROTECTED:
        return RES_WRPRT;
    default:
        return RES_ERROR;
    }
}

uint32_t sd_sectors(CSD csd)
{
    uint32_t size;
    uint8_t ver = csd[0] >> 6;
    if (ver == 0) {
        size = (uint32_t)(csd[6] & 3) << 10;
        size |= (uint32_t)csd[7] << 2 | csd[8] >> 6;
        uint8_t size_mult = (csd[9] & 3) << 1 | csd[10] >> 7;
        uint8_t read_bl_len = csd[5] & 15;
        return (size + 1) << (size_mult + read_bl_len + 2 - 9);
    } else if (ver == 1) {
        size = (uint32_t)(csd[7] & 63) << 16;
        size |= (uint32_t)csd[8] << 8;
        size |= csd[9];
        return (size + 1) << 10;
    } else {
        return 0;
    }
}
