#include "fpga_api.h"
#include <errno.h>
#include <gpio.h>
#include <qspi.h>
#include <stddef.h>
#include <stdlib.h>

#define BUF_SIZE 512

int fpga_api_write_mem(uint32_t address, uint32_t size, fpga_api_reader_cb cb, void *arg)
{
    static uint8_t buf[2][BUF_SIZE * 2];
    uint8_t buf_idx = 0;
    uint32_t remain = size;
    uint32_t offset = address;
    bool pending_write = false;
    int rc = 0;

    while (remain > 0) {
        uint32_t chunk = remain > BUF_SIZE ? BUF_SIZE : remain;
        if (!cb(buf[buf_idx], chunk, arg)) {
            rc = -EIO;
            goto out;
        }

        if (pending_write) {
            if ((rc = qspi_write_end()) != 0) {
                goto out;
            }
        }
        if ((rc = qspi_write_begin(CMD_WRITE_MEM, offset, buf[buf_idx], chunk)) != 0) {
            goto out;
        }
        pending_write = true;

        // Swap between two buffers for double-buffering
        buf_idx = !buf_idx;
        offset += chunk;
        remain -= chunk;
    }

    if (pending_write) {
        if ((rc = qspi_write_end()) != 0) {
            goto out;
        }
    }
out:
    return rc;
}

int fpga_api_read_mem(uint32_t address, uint32_t size, fpga_api_writer_cb cb, void *arg)
{
    static uint8_t buf[2][BUF_SIZE];
    uint32_t remain = size;
    uint32_t offset = address;
    int rc = 0;
    uint8_t buf_idx = 0;

    uint32_t chunk = remain > BUF_SIZE ? BUF_SIZE : remain;
    if ((rc = qspi_read_begin(CMD_READ_MEM, offset, buf[buf_idx], chunk)) != 0) {
        goto out;
    }

    while (remain > 0) {
        if ((rc = qspi_read_end()) != 0) {
            goto out;
        }

        uint32_t current_chunk = chunk;
        uint8_t current_buf_idx = buf_idx;

        offset += current_chunk;
        remain -= current_chunk;
        buf_idx = !buf_idx;

        if (remain > 0) {
            chunk = remain > BUF_SIZE ? BUF_SIZE : remain;
            if ((rc = qspi_read_begin(CMD_READ_MEM, offset, buf[buf_idx], chunk)) != 0) {
                goto out;
            }
        }

        if (!cb(buf[current_buf_idx], current_chunk, arg)) {
            rc = -EIO;
            if (remain > 0) {
                qspi_read_end();
            }
            goto out;
        }
    }
out:
    return rc;
}

int fpga_api_read_reg(enum fpga_reg_id id, uint32_t *value)
{
    return qspi_read(CMD_READ_REG, id, (uint8_t *)value, sizeof(uint32_t));
}

int fpga_api_write_reg(enum fpga_reg_id id, uint32_t value)
{
    return qspi_write(CMD_WRITE_REG, id, (uint8_t *)&value, sizeof(value));
}

uint32_t fpga_api_ev_reg(void)
{
    static uint32_t cached_events;
    static bool events_initialized;

    if (irq_called() || !events_initialized) {
        if (fpga_api_read_reg(FPGA_REG_EVENTS, &cached_events) == 0) {
            events_initialized = true;
        }
    }
    return cached_events;
}
