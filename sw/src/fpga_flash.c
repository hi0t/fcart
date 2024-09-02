#include "fpga_flash.h"
#include "altera.h"
#include "trace.h"
#include <hardware/gpio.h>
#include <pico/multicore.h>
#include <stdlib.h>
#include <zlib.h>

#define JTAG_PIN_TCK 6
#define JTAG_PIN_TDO 7
#define JTAG_PIN_TMS 8
#define JTAG_PIN_TDI 9

// Embedding fpga configuration into binary
// clang-format off
#define INCBIN(name, file)                      \
    __asm__(".section .rodata\n"                \
            ".global _binary_" #name "_start\n" \
            ".balign 16\n"                      \
            "_binary_" #name "_start:\n"        \
            ".incbin \"" file "\"\n"            \
            ".global _binary_" #name "_end\n"   \
            ".balign 1\n"                       \
            "_binary_" #name "_end:\n"          \
            ".byte 0\n");                       \
    extern __attribute__((aligned(16))) const uint8_t _binary_##name##_start[]; \
    extern const uint8_t _binary_##name##_end[]
// clang-format on

INCBIN(loader, LOADER_ARCHIVE_PATH);
INCBIN(fcart, FCART_ARCHIVE_PATH);

// Write in one buffer and read from another.
struct inflate_data {
    uint8_t *buf;
    uint16_t sz;
    bool last;
    bool err;
};

static struct inflate_data inflate_res[2];
static uint16_t inflate_chunk;
static const uint8_t *inflate_start, *inflate_end;
static void inflate_thread()
{
    multicore_fifo_drain();

    z_stream strm;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.avail_in = inflate_end - inflate_start;
    strm.next_in = inflate_start;

    inflateInit2(&strm, 16 + MAX_WBITS);
    bool curr_buf = 0;

    for (;;) {
        struct inflate_data *res = &inflate_res[curr_buf];

        strm.next_out = res->buf;
        strm.avail_out = inflate_chunk;

        int ret = inflate(&strm, Z_NO_FLUSH);
        if (ret != Z_OK && ret != Z_STREAM_END) {
            TRACE("zlib error (%d): %s", ret, strm.msg);
        }

        res->sz = inflate_chunk - strm.avail_out;
        res->last = (ret == Z_STREAM_END);
        res->err = (ret != Z_OK && ret != Z_STREAM_END);
        multicore_fifo_push_blocking(curr_buf);
        curr_buf ^= 1;

        if (ret != Z_OK) {
            break;
        }
        if (multicore_fifo_pop_blocking() != 0) {
            break;
        }
    }
    inflateEnd(&strm);
    TRACE("zlib finish");
}

static void start_inflate(uint16_t chunk, const uint8_t *start_addr, const uint8_t *end_addr)
{
    inflate_res[0].buf = malloc(chunk);
    inflate_res[1].buf = malloc(chunk);

    inflate_start = start_addr;
    inflate_end = end_addr;
    inflate_chunk = chunk;
    multicore_reset_core1();
    multicore_launch_core1(inflate_thread);
}

static void stop_inflate(bool abort)
{
    if (abort) {
        multicore_fifo_push_blocking(1);
    }
    multicore_fifo_drain();
    free(inflate_res[0].buf);
    free(inflate_res[1].buf);
}

static int32_t push_loader(uint32_t **buf, bool *last)
{
    uint32_t n = multicore_fifo_pop_blocking();
    struct inflate_data *res = &inflate_res[n];
    if (res->err) {
        return -1;
    }
    *buf = (uint32_t *)res->buf;
    *last = res->last;
    multicore_fifo_push_blocking(0);
    return res->sz;
}

static bool write_enable()
{
    alt_flash_exec(0x06, 0);
    return alt_flash_wait(0x05, 0x02, 0x02, 15);
}

// 32KB Blocks Erase
static bool blocks_erase(uint32_t addr, uint32_t nbytes)
{
    for (uint32_t block = addr; block < nbytes; block += 0x8000) {
        if (!write_enable()) {
            TRACE("fpga_flash: we error while block erase");
            return false;
        }
        alt_flash_rw(0x52, block, NULL, NULL, 0);
        if (!alt_flash_wait(0x05, 0x00, 0x01, 1600)) {
            TRACE("fpga_flash: block erase timeout");
            return false;
        }
    }
    return true;
}

static bool page_program(uint32_t addr, uint32_t *data, uint32_t nbytes)
{
    assert(nbytes <= 256);
    if (!write_enable()) {
        TRACE("fpga_flash: we error while page program");
        return false;
    }
    alt_flash_rw(0x02, addr, data, NULL, nbytes);
    if (!alt_flash_wait(0x05, 0x00, 0x01, 3)) {
        TRACE("fpga_flash: page program timeout");
        return false;
    }
    return true;
}

static bool flash_program()
{
    start_inflate(256, _binary_fcart_start, _binary_fcart_end);

    struct inflate_data *res;
    uint32_t addr = 0;
    bool ret = true;
    do {
        uint32_t n = multicore_fifo_pop_blocking();
        res = &inflate_res[n];
        if (res->err) {
            ret = false;
            goto out;
        }
        multicore_fifo_push_blocking(0);

        if (!page_program(addr, (uint32_t *)res->buf, res->sz)) {
            ret = false;
            goto out;
        }
        addr += res->sz;
    } while (!res->last);

out:
    stop_inflate(!ret);
    return ret;
}

static uint32_t calc_crc(uint32_t size)
{
    uint8_t buf[256];
    uLong crc = crc32(0L, Z_NULL, 0);

    for (uint32_t addr = 0; addr < size; addr += 256) {
        uint32_t sz = (size - addr) < 256 ? (size - addr) : 256;
        alt_flash_rw(0x03, addr, NULL, (uint32_t *)buf, sz);
        crc = crc32(crc, buf, sz);
    }
    return crc;
}

bool fpga_flash()
{
    // Launch unzip in a separate core
    start_inflate(512, _binary_loader_start, _binary_loader_end);

    alt_init(6, 7, 8, 9);
    if (!alt_scan()) {
        TRACE("fpga not found");
        return false;
    }
    if (!alt_program_mem(push_loader)) {
        TRACE("fpga_flash: error while programming the loader");
        return false;
    }

    stop_inflate(false);

    // Reset
    alt_flash_exec(0x66, 0);
    alt_flash_exec(0x99, 0);
    alt_flash_exec(0xAB, 0);

    uint32_t id = alt_flash_exec(0x9F, 3);
    if (id != 0xEF4017) {
        TRACE("fpga_flash: unsupported memory: 0x%08lx", id);
        return false;
    }

    uint32_t status = alt_flash_exec(0x05, 1);
    if (status != 0) {
        TRACE("fpga_flash: write protection set: %lu", status);
        return false;
    }

    uint32_t size = *(uint32_t *)(_binary_fcart_end - 4);
    if (!blocks_erase(0, size)) {
        return false;
    }

    if (!flash_program()) {
        return false;
    }

    uint32_t crc = *(uint32_t *)(_binary_fcart_end - 8);
    if (calc_crc(size) != crc) {
        TRACE("fpga_flash: checksum mismatch");
        return false;
    }

    alt_reset();
    return true;
}
