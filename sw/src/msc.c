#include "diskio.h"
#include "ui.h"
#include <tusb.h>

void tud_umount_cb()
{
    ui_set_usb_mode(false);
}

// Invoked when received SCSI_CMD_INQUIRY, v2 with full inquiry response
// Some inquiry_resp's fields are already filled with default values, application can update them
// Return length of inquiry response, typically sizeof(scsi_inquiry_resp_t) (36 bytes), can be longer if included vendor data.
uint32_t tud_msc_inquiry2_cb(uint8_t lun, scsi_inquiry_resp_t *inquiry_resp, uint32_t bufsize)
{
    (void)lun;
    (void)bufsize;
    const char *vid = "fcart";
    const char *pid = "SD card";
    const char *rev = "1.0";

    memcpy(inquiry_resp->vendor_id, vid, strlen(vid));
    memcpy(inquiry_resp->product_id, pid, strlen(pid));
    memcpy(inquiry_resp->product_rev, rev, strlen(rev));

    return sizeof(scsi_inquiry_resp_t); // 36 bytes
}

// Invoked when received Test Unit Ready command.
// return true allowing host to read/write this LUN e.g SD card inserted
bool tud_msc_test_unit_ready_cb(uint8_t lun)
{
    (void)lun;

    if (disk_status(0) & STA_NOINIT) {
        disk_initialize(0);
    }

    return (disk_status(0) & STA_NOINIT) == 0;
}

// Invoked when received SCSI_CMD_READ_CAPACITY_10 and SCSI_CMD_READ_FORMAT_CAPACITY to determine the disk size
// Application update block count and block size
void tud_msc_capacity_cb(uint8_t lun, uint32_t *block_count, uint16_t *block_size)
{
    (void)lun;
    DWORD count;
    WORD size;

    if (disk_ioctl(0, GET_SECTOR_COUNT, &count) == RES_OK) {
        *block_count = count;
    } else {
        *block_count = 0;
    }

    if (disk_ioctl(0, GET_SECTOR_SIZE, &size) == RES_OK) {
        *block_size = size;
    } else {
        *block_size = 512;
    }
}

// Invoked when received Start Stop Unit command
// - Start = 0 : stopped power mode, if load_eject = 1 : unload disk storage
// - Start = 1 : active mode, if load_eject = 1 : load disk storage
bool tud_msc_start_stop_cb(uint8_t lun, uint8_t power_condition, bool start, bool load_eject)
{
    (void)lun;
    (void)power_condition;

    if (load_eject) {
        if (start) {
            ui_set_usb_mode(true);
        } else {
            ui_set_usb_mode(false);
        }
    }

    return true;
}

// Callback invoked when received READ10 command.
// Copy disk's data to buffer (up to bufsize) and return number of copied bytes.
int32_t tud_msc_read10_cb(uint8_t lun, uint32_t lba, uint32_t offset, void *buffer, uint32_t bufsize)
{
    (void)lun;
    (void)offset;

    // offset should be 0 for standard block reads
    uint32_t count = bufsize / 512;
    if (disk_read(0, buffer, lba, count) != RES_OK) {
        return -1;
    }

    return bufsize;
}

bool tud_msc_is_writable_cb(uint8_t lun)
{
    (void)lun;
    return (disk_status(0) & STA_PROTECT) == 0;
}

// Callback invoked when received WRITE10 command.
// Process data in buffer to disk's storage and return number of written bytes
int32_t tud_msc_write10_cb(uint8_t lun, uint32_t lba, uint32_t offset, uint8_t *buffer, uint32_t bufsize)
{
    (void)lun;
    (void)offset;

    uint32_t count = bufsize / 512;
    if (disk_write(0, buffer, lba, count) != RES_OK) {
        return -1;
    }

    return bufsize;
}

// Callback invoked when received an SCSI command not in built-in list below
// - READ_CAPACITY10, READ_FORMAT_CAPACITY, INQUIRY, MODE_SENSE6, REQUEST_SENSE
// - READ10 and WRITE10 has their own callbacks
int32_t tud_msc_scsi_cb(uint8_t lun, uint8_t const scsi_cmd[16], void *buffer, uint16_t bufsize)
{
    (void)lun;
    (void)scsi_cmd;
    (void)buffer;
    (void)bufsize;

    // currently no other commands is supported

    // Set Sense = Invalid Command Operation
    (void)tud_msc_set_sense(lun, SCSI_SENSE_ILLEGAL_REQUEST, 0x20, 0x00);

    return -1; // stall/failed command request;
}
