#include "fpga_cfg.h"
#include "log.h"
#include <errno.h>
#include <soc.h>
#include <spi.h>
#include <stdbool.h>
#include <string.h>

LOG_MODULE(fpga_cfg);

#define IDCODE_PUB { 0xE0, 0x00, 0x00, 0x00 }
#define LSC_READ_STATUS { 0x3C, 0x00, 0x00, 0x00 }
#define ISC_ENABLE_X { 0x74, 0x08, 0x00, 0x00 }
#define ISC_ERASE { 0x0E, 0x04, 0x00, 0x00 } // 0x12 for cfg and UFM
#define LSC_INITADDRESS { 0x46, 0x00, 0x00, 0x00 }
#define LSC_PROG_INCR_NV { 0x70, 0x00, 0x00, 0x01 }
#define ISC_PROGRAM_DONE { 0x5E, 0x00, 0x00, 0x00 }
#define ISC_DISABLE { 0x26, 0x00, 0x00 }
#define LSC_REFRESH { 0x79, 0x00, 0x00 }

#define PAGE_SIZE 16

enum status_bit {
    BIT_DONE = 8,
    BIT_BUSY = 12,
    BIT_FAIL = 13,
};

static int read_device_id(uint32_t *id);
static int get_status(uint32_t *status);
static bool test_bit(uint32_t status, enum status_bit bit);
static int enable_cfg_interface();
static int disable_cfg_interface();
static int init_address();
static int write_page(uint8_t *data);
static int program_done();
static int erase_flash();
static int refresh();
static void cleanup();
static void dump_status(uint32_t status);

int fpga_cfg_start()
{
    uint32_t id, status;
    int rc;

    LOG_INF("Initializing FPGA flash...");
    get_status(&status);
    dump_status(status);

    if ((rc = read_device_id(&id)) != 0) {
        return rc;
    }
    LOG_INF("FPGA ID: %08X", id);

    if (id != 0x012BC043) {
        LOG_ERR("Invalid FPGA ID");
        return -ENODEV;
    }

    if ((rc = enable_cfg_interface()) != 0) {
        return rc;
    }

    if ((rc = erase_flash()) != 0) {
        return rc;
    }

    if ((rc = get_status(&status)) != 0) {
        return rc;
    }
    dump_status(status);
    if (test_bit(status, BIT_FAIL)) {
        LOG_ERR("FPGA flash erase failed");
        return -EINVAL;
    }

    // When programming the UFM, must make this call again.
    rc = init_address();

    get_status(&status);
    dump_status(status);
    return rc;
}

int fpga_cfg_write(uint8_t *data, uint32_t len)
{
    uint8_t tail_buf[PAGE_SIZE] = { [0 ... PAGE_SIZE - 1] = 0xFF };
    uint8_t *tx;
    uint32_t status;
    int rc;

    LOG_INF("Writing %u bytes to FPGA flash", len);
    get_status(&status);
    dump_status(status);

    for (uint32_t offset = 0; offset < len; offset += PAGE_SIZE) {
        if (len - offset < PAGE_SIZE) {
            memcpy(tail_buf, &data[offset], len - offset);
            tx = tail_buf;
        } else {
            tx = &data[offset];
        }
        if ((rc = write_page(tx)) != 0) {
            return rc;
        }
    }

    get_status(&status);
    dump_status(status);
    return 0;
}

int fpga_cfg_done()
{
    uint32_t status;
    int rc;

    LOG_INF("Finalizing FPGA flash programming...");

    if ((rc = program_done()) != 0) {
        return rc;
    }

    if ((rc = get_status(&status)) != 0) {
        return rc;
    }
    dump_status(status);
    if (!test_bit(status, BIT_DONE)) {
        LOG_ERR("FPGA flash programming failed");
        cleanup();
        return -EINVAL;
    }

    // If offline programming is to be used, a LSC_REFRESH must be do instead of this call.
    rc = disable_cfg_interface();

    get_status(&status);
    dump_status(status);
    return rc;
}

static uint32_t to_le(uint8_t word[4])
{
    return ((word[0] << 24U) | (word[1] << 16U) | (word[2] << 8U) | word[3]);
}

static int read_device_id(uint32_t *id)
{
    uint8_t buf[] = IDCODE_PUB;
    int rc;

    spi_begin();
    if ((rc = spi_send(buf, sizeof(buf))) != 0) {
        goto out;
    }
    if ((rc = spi_recv(buf, sizeof(buf))) != 0) {
        goto out;
    }
    *id = to_le(buf);
out:
    spi_end();
    return rc;
}

static int get_status(uint32_t *status)
{
    uint8_t buf[] = LSC_READ_STATUS;
    int rc;

    spi_begin();
    if ((rc = spi_send(buf, sizeof(buf))) != 0) {
        goto out;
    }
    if ((rc = spi_recv(buf, sizeof(buf))) != 0) {
        goto out;
    }
    *status = to_le(buf);
out:
    spi_end();
    return rc;
}

static bool test_bit(uint32_t status, enum status_bit bit)
{
    return (status & (1U << bit)) != 0;
}

static int wait_until_ready(uint32_t poll_us)
{
    uint32_t status;
    int rc;
    int retry_count = 0;

    do {
        if ((rc = get_status(&status)) != 0) {
            return rc;
        }
        if (++retry_count >= 10) {
            LOG_ERR("Timeout waiting for FPGA to become ready");
            return -EBUSY;
        }
        if (poll_us > 1000U) {
            delay_ms(poll_us / 1000U);
        } else {
            delay_us(poll_us);
        }
    } while (test_bit(status, BIT_BUSY));

    return 0;
}

static int enable_cfg_interface()
{
    uint8_t buf[] = ISC_ENABLE_X;
    int rc;

    spi_begin();
    rc = spi_send(buf, sizeof(buf));
    spi_end();

    return rc == 0 ? wait_until_ready(2U) : rc;
}

static int disable_cfg_interface()
{
    uint8_t buf[] = ISC_DISABLE;
    int rc;

    spi_begin();
    rc = spi_send(buf, sizeof(buf));
    spi_end();

    return rc;
}

static int init_address()
{
    uint8_t buf[] = LSC_INITADDRESS;
    int rc;

    spi_begin();
    rc = spi_send(buf, sizeof(buf));
    spi_end();

    return rc;
}

static int write_page(uint8_t *data)
{
    uint8_t cmd[] = LSC_PROG_INCR_NV;
    int rc;

    spi_begin();
    if ((rc = spi_send(cmd, sizeof(cmd))) != 0) {
        spi_end();
        return rc;
    }
    rc = spi_send(data, PAGE_SIZE);
    spi_end();

    // The operation takes 200 us.
    // Therefore we will poll every 50 us.
    return rc == 0 ? wait_until_ready(50U) : rc;
}

static int program_done()
{
    uint8_t buf[] = ISC_PROGRAM_DONE;
    int rc;

    spi_begin();
    rc = spi_send(buf, sizeof(buf));
    spi_end();

    return rc == 0 ? wait_until_ready(50U) : rc;
}

static int erase_flash()
{
    uint8_t buf[] = ISC_ERASE;
    int rc;

    spi_begin();
    rc = spi_send(buf, sizeof(buf));
    spi_end();

    // Takes 5 seconds for the largest device.
    return rc == 0 ? wait_until_ready(1000U * 1000U) : rc;
}

static int refresh()
{
    uint8_t buf[] = LSC_REFRESH;
    int rc;

    spi_begin();
    rc = spi_send(buf, sizeof(buf));
    spi_end();

    // Takes a few milliseconds depending on the model.
    // We will poll once per millisecond.
    return rc == 0 ? wait_until_ready(1000U) : rc;
}

static void cleanup()
{
    LOG_INF("Cleaning up FPGA flash state...");

    if (erase_flash() == 0) {
        refresh();
    }
}

static const char *err_string(uint8_t err)
{
    switch (err) {
    case 0:
        return "No Error";
    case 1:
        return "ID ERR";
    case 2:
        return "CMD ERR";
    case 3:
        return "CRC ERR";
    case 4:
        return "Preamble ERR";
    case 5:
        return "Abort ERR";
    case 6:
        return "Overflow ERR";
    case 7:
        return "SDM EOF";
    default:
        return "Unknown Error";
    }
}

static void dump_status(uint32_t status)
{
    LOG_INF("FPGA flash status: %08X", status);
    LOG_INF("  DONE: %d", test_bit(status, BIT_DONE));
    LOG_INF("  ISC Enable: %d", test_bit(status, 9U));
    LOG_INF("  BUSY: %d", test_bit(status, BIT_BUSY));
    LOG_INF("  FAIL: %d", test_bit(status, BIT_FAIL));
    LOG_INF("  ID Error: %d", test_bit(status, 27U));
    LOG_INF("  Error: %s", err_string((status >> 23U) & 7U));
}
