#include "err.h"
#include <errno.h>

int fresult_to_errno(FRESULT rc)
{
    switch (rc) {
    case FR_OK:
        return 0;
    case FR_DISK_ERR:
        return EIO;
    case FR_INT_ERR:
        return EFAULT;
    case FR_NOT_READY:
        return EBUSY;
    case FR_NO_FILE:
        return ENOENT;
    case FR_NO_PATH:
        return ENOENT;
    case FR_INVALID_NAME:
        return EINVAL;
    case FR_DENIED:
        return EACCES;
    case FR_EXIST:
        return EEXIST;
    case FR_INVALID_OBJECT:
        return EINVAL;
    case FR_WRITE_PROTECTED:
        return EROFS;
    case FR_INVALID_DRIVE:
        return ENODEV;
    case FR_NOT_ENABLED:
        return ENODEV;
    case FR_NO_FILESYSTEM:
        return ENODEV;
    case FR_MKFS_ABORTED:
        return EIO;
    case FR_TIMEOUT:
        return ETIMEDOUT;
    case FR_LOCKED:
        return EBUSY;
    case FR_NOT_ENOUGH_CORE:
        return ENOMEM;
    case FR_TOO_MANY_OPEN_FILES:
        return EMFILE;
    case FR_INVALID_PARAMETER:
        return EINVAL;
    default:
        return EIO;
    }
}
