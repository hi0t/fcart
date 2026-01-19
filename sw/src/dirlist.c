#include "dirlist.h"
#include "drivers/qspi.h"
#include "fpga_api.h"
#include "gfx.h"
#include <errno.h>
#include <ff.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct arr {
    uint32_t *items;
    uint16_t capacity;
    uint16_t count;
};

#define arr_append(a, v)                                               \
    do {                                                               \
        if (a.count >= a.capacity) {                                   \
            a.capacity = a.capacity == 0 ? 256 : a.capacity * 2;       \
            a.items = realloc(a.items, a.capacity * sizeof(*a.items)); \
        }                                                              \
        a.items[a.count++] = v;                                        \
    } while (0)

static struct arr items;
static uint16_t dir_count;
static char *curr_path;

typedef struct {
    uint32_t addr;
    char cache[11];
    uint8_t is_dir;
} cached_entry_t;

static int names_cmp(const void *a, const void *b);
static int readdir();

int dirlist_load()
{
    if (curr_path != NULL) {
        free(curr_path);
    }
    curr_path = malloc(1);
    curr_path[0] = '\0';

    return readdir();
}

int dirlist_push(const char *subdir)
{
    uint16_t subdir_len = strlen(subdir);
    uint16_t curr_path_len = strlen(curr_path);
    char *new_curr_path = malloc(curr_path_len + subdir_len + 2);
    if (new_curr_path == NULL) {
        return -ENOMEM;
    }

    strcpy(new_curr_path, curr_path);
    new_curr_path[curr_path_len] = '/';
    strcpy(&new_curr_path[curr_path_len + 1], subdir);

    free(curr_path);
    curr_path = new_curr_path;

    return readdir();
}

int dirlist_pop()
{
    char *last_slash = strrchr(curr_path, '/');
    if (last_slash != NULL) {
        *last_slash = '\0';
    } else {
        curr_path[0] = '\0';
    }
    return readdir();
}

uint16_t dirlist_size()
{
    return items.count;
}

uint8_t dirlist_select(uint16_t index, uint8_t limit, struct dirlist_entry *out)
{
    if (index >= items.count) {
        return 0; // Index out of bounds
    }

    uint8_t count = 0;
    uint16_t curr_index = index;

    while ((count < limit) && (curr_index < items.count)) {
        qspi_read(CMD_READ_MEM, items.items[curr_index], (uint8_t *)out[count].name, sizeof(out[count].name));
        out[count].is_dir = (curr_index < dir_count);

        count++;
        curr_index++;
    }
    return count; // Return number of entries filled
}

char *dirlist_file_path(struct dirlist_entry *entry)
{
    uint16_t curr_path_len = strlen(curr_path);
    uint16_t name_len = strlen(entry->name);
    char *full_path = malloc(curr_path_len + name_len + 2);
    if (full_path == NULL) {
        return NULL;
    }

    if (curr_path_len > 0) {
        strcpy(full_path, curr_path);
    }
    full_path[curr_path_len] = '/';
    strcpy(&full_path[curr_path_len + 1], entry->name);

    return full_path;
}

static int names_cmp(const void *a, const void *b)
{
    const cached_entry_t *ca = a;
    const cached_entry_t *cb = b;

    if (ca->is_dir != cb->is_dir) {
        return cb->is_dir - ca->is_dir;
    }

    int r = strncmp(ca->cache, cb->cache, sizeof(ca->cache));
    if (r != 0) {
        return r;
    }

    // Fallback to QSPI read
    char buf_a[256];
    char buf_b[256];
    qspi_read(CMD_READ_MEM, ca->addr, (uint8_t *)buf_a, sizeof(buf_a));
    qspi_read(CMD_READ_MEM, cb->addr, (uint8_t *)buf_b, sizeof(buf_b));
    return strcmp(buf_a, buf_b);
}

static int readdir()
{
    DIR dir;
    FILINFO fno;
    int r = 0;
    uint32_t sdram_addr = 0;

    if (f_opendir(&dir, curr_path) != FR_OK) {
        return false;
    }

    // Reset lists
    items.count = 0;
    dir_count = 0;

    struct {
        cached_entry_t *items;
        uint16_t capacity;
        uint16_t count;
    } cache_entries = { 0 };

    static uint8_t buf[4096];
    uint16_t buf_len = 0;

    for (;;) {
        if (f_readdir(&dir, &fno) != FR_OK || fno.fname[0] == 0) {
            break;
        }
        if (fno.fname[0] == '.' || (fno.fattrib & AM_HID) || (fno.fattrib & AM_SYS)) {
            continue; // Skip hidden files
        }

        uint16_t name_len = strlen(fno.fname) + 1;
        uint16_t needed = name_len + (name_len % 2);

        if (buf_len + needed > sizeof(buf)) {
            if ((r = qspi_write(CMD_WRITE_MEM, sdram_addr, buf, buf_len)) != 0) {
                goto out;
            }
            sdram_addr += buf_len;
            buf_len = 0;
        }

        cached_entry_t entry;
        entry.addr = sdram_addr + buf_len;
        entry.is_dir = (fno.fattrib & AM_DIR) ? 1 : 0;
        memcpy(entry.cache, fno.fname, sizeof(entry.cache));

        arr_append(cache_entries, entry);
        if (cache_entries.items == NULL || cache_entries.count == UINT16_MAX) {
            r = -ENOSPC;
            goto out;
        }

        strcpy((char *)&buf[buf_len], fno.fname);
        if (needed > name_len)
            buf[buf_len + name_len] = 0;
        buf_len += needed;
    }

    if (buf_len > 0) {
        if ((r = qspi_write(CMD_WRITE_MEM, sdram_addr, buf, buf_len)) != 0) {
            goto out;
        }
    }

    if (cache_entries.count > 0)
        qsort(cache_entries.items, cache_entries.count, sizeof(cached_entry_t), names_cmp);

    for (uint16_t i = 0; i < cache_entries.count; i++) {
        arr_append(items, cache_entries.items[i].addr);
        if (cache_entries.items[i].is_dir) {
            dir_count++;
        }
    }
out:
    if (cache_entries.items)
        free(cache_entries.items);
    f_closedir(&dir);
    return r;
}
