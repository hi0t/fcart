#include "dirlist.h"
#include "drivers/qspi.h"
#include "fpga_api.h"
#include "gfx.h"
#include <ff.h>
#include <stdlib.h>
#include <string.h>

struct arr {
    uint32_t *entries;
    uint16_t capacity;
    uint16_t count;
};

#define arr_append(a, v)                                                     \
    do {                                                                     \
        if (a.count >= a.capacity) {                                         \
            a.capacity = a.capacity == 0 ? 256 : a.capacity * 2;             \
            a.entries = realloc(a.entries, a.capacity * sizeof(*a.entries)); \
        }                                                                    \
        a.entries[a.count++] = v;                                            \
    } while (0)

static struct arr dirs;
static struct arr files;
static uint8_t buffer[512];
static char *curr_path;

static int names_cmp(const void *a, const void *b);
static bool readdir();

bool dirlist_load()
{
    if (curr_path != NULL) {
        free(curr_path);
    }
    curr_path = malloc(1);
    curr_path[0] = '\0';

    return readdir();
}

bool dirlist_push(const char *subdir)
{
    uint16_t subdir_len = strlen(subdir);
    uint16_t curr_path_len = strlen(curr_path);
    char *new_curr_path = malloc(curr_path_len + subdir_len + 2);
    if (new_curr_path == NULL) {
        return false;
    }

    strcpy(new_curr_path, curr_path);
    new_curr_path[curr_path_len] = '/';
    strcpy(&new_curr_path[curr_path_len + 1], subdir);

    free(curr_path);
    curr_path = new_curr_path;

    return readdir();
}

bool dirlist_pop()
{
    char *last_slash = strrchr(curr_path, '/');
    if (last_slash != NULL) {
        *last_slash = '\0';
    } else {
        curr_path[0] = '\0';
    }
    return readdir();
}

uint32_t dirlist_size()
{
    return dirs.count + files.count;
}

uint8_t dirlist_select(uint32_t index, uint8_t limit, struct dirlist_entry *out)
{
    if (index >= dirs.count + files.count) {
        return 0; // Index out of bounds
    }

    uint8_t count = 0;
    uint32_t curr_index = index;

    while ((count < limit) && (curr_index < dirs.count + files.count)) {
        if (curr_index < dirs.count) {
            // Directory
            qspi_read(CMD_READ_MEM, dirs.entries[curr_index], (uint8_t *)out[count].name, sizeof(out[count].name));
            out[count].is_dir = true;
        } else {
            // File
            qspi_read(CMD_READ_MEM, files.entries[curr_index - dirs.count], (uint8_t *)out[count].name, sizeof(out[count].name));
            out[count].is_dir = false;
        }

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
    uint32_t offset_a = *(const uint32_t *)a;
    uint32_t offset_b = *(const uint32_t *)b;

    uint8_t *buf_a = buffer;
    uint8_t *buf_b = buffer + 256;

    qspi_read(CMD_READ_MEM, offset_a, buf_a, 256);
    qspi_read(CMD_READ_MEM, offset_b, buf_b, 256);

    return strcmp((char *)buf_a, (char *)buf_b);
}

static bool readdir()
{
    DIR dir;
    FILINFO fno;
    bool r = true;
    uint32_t sdram_addr = FRAMEBUFFER_CAPACITY; // Start after framebuffer

    if (f_opendir(&dir, curr_path) != FR_OK) {
        return false;
    }

    // Reset lists
    dirs.count = 0;
    files.count = 0;

    for (;;) {
        if (f_readdir(&dir, &fno) != FR_OK || fno.fname[0] == 0) {
            break;
        }
        if (fno.fname[0] == '.' || (fno.fattrib & AM_HID) || (fno.fattrib & AM_SYS)) {
            continue; // Skip hidden files
        }

        uint16_t name_len = strlen(fno.fname) + 1;
        memcpy(buffer, fno.fname, name_len);
        if (name_len % 2 != 0) {
            buffer[name_len++] = 0;
        }
        if (qspi_write(CMD_WRITE_MEM, sdram_addr, buffer, name_len) != 0) {
            r = false;
            goto out;
        }

        if (fno.fattrib & AM_DIR) {
            // Handle directory
            arr_append(dirs, sdram_addr);
        } else {
            // Handle file
            arr_append(files, sdram_addr);
        }

        sdram_addr += name_len;
    }

    qsort(dirs.entries, dirs.count, sizeof(uint32_t), names_cmp);
    qsort(files.entries, files.count, sizeof(uint32_t), names_cmp);
out:
    f_closedir(&dir);
    return r;
}
