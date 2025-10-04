#include "fpga_api.h"
#include <errno.h>
#include <gpio.h>
#include <qspi.h>
#include <stddef.h>
#include <stdlib.h>

enum {
    CMD_WRITE_MEM = 1,
    CMD_READ_REG,
    CMD_WRITE_REG
};

int fpga_api_write_mem(uint32_t address, uint32_t size, fpga_api_reader_cb cb, void *arg)
{
#define BUF_SIZE 1024
    uint8_t *buf = malloc(BUF_SIZE);
    uint32_t remain = size;
    uint32_t offset = address;
    int rc = 0;

    while (remain > 0) {
        uint32_t chunk = remain > BUF_SIZE ? BUF_SIZE : remain;
        if (!cb(buf, chunk, arg)) {
            rc = -EIO;
            goto out;
        }
        // TODO: make parallel transfer
        if ((rc = qspi_write(CMD_WRITE_MEM, offset, buf, chunk)) != 0) {
            goto out;
        }
        offset += chunk;
        remain -= chunk;
    }
out:
    free(buf);
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

uint32_t fpga_api_ev_reg()
{
    static uint32_t events;

    if (!irq_called()) {
        return events;
    }

    fpga_api_read_reg(FPGA_REG_EVENTS, &events);
    return events;
}
