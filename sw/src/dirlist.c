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

#define arr_append(a, v)                                                                   \
    do {                                                                                   \
        if ((a).count >= (a).capacity) {                                                   \
            uint16_t new_capacity = ((a).capacity == 0) ? 16 : (a).capacity * 2;           \
            void *new_entries = realloc((a).entries, new_capacity * sizeof(*(a).entries)); \
            if (new_entries == NULL) {                                                     \
                break;                                                                     \
            }                                                                              \
            (a).entries = new_entries;                                                     \
            (a).capacity = new_capacity;                                                   \
        }                                                                                  \
        (a).entries[(a).count++] = (v);                                                    \
    } while (0)

static struct arr dirs;
static struct arr files;
static uint8_t buffer[2][512];
static char *names;
static uint32_t names_capacity;
static char *curr_path;

static int names_cmp(const void *a, const void *b);
static bool readdir();

bool dirlist_load()
{
    if (names != NULL) {
        free(names);
    }
    names = malloc(8192); // TODO: place names in SDRAM
    names_capacity = 8192;

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
            out[count].name = &names[dirs.entries[curr_index]];
            out[count].is_dir = true;
        } else {
            // File
            out[count].name = &names[files.entries[curr_index - dirs.count]];
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

    qspi_read(CMD_READ_MEM, offset_a, buffer[0], 256);
    qspi_read(CMD_READ_MEM, offset_b, buffer[1], 256);

    return strcmp((char *)buffer[0], (char *)buffer[1]);
}

static bool readdir()
{
    DIR dir;
    FILINFO fno;
    bool r = true;
    uint8_t buf_idx = 0;
    uint16_t buf_pos = 0;
    uint32_t sdram_addr = FB_SIZE; // Start after framebuffer
    bool transfer_active = false;

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
        uint8_t name_len = strlen(fno.fname);

        // Check if buffer full (ensure we have space for name + null + potential padding)
        if (buf_pos + name_len + 2 > 512) {
            // Wait for previous transfer to complete
            if (transfer_active) {
                qspi_write_end();
                transfer_active = false;
            }

            if (qspi_write_begin(CMD_WRITE_MEM, sdram_addr, buffer[buf_idx], buf_pos) != 0) {
                r = false;
                goto out;
            }
            transfer_active = true;

            sdram_addr += buf_pos;
            buf_pos = 0;
            buf_idx = !buf_idx;
        }

        // Copy name to buffer
        memcpy(&buffer[buf_idx][buf_pos], fno.fname, name_len + 1);

        // Store offset (absolute SDRAM address)
        uint32_t current_offset = sdram_addr + buf_pos;

        if (fno.fattrib & AM_DIR) {
            // Handle directory
            arr_append(dirs, current_offset);
        } else {
            // Handle file
            arr_append(files, current_offset);
        }

        buf_pos += name_len + 1;
        if (buf_pos % 2 != 0) {
            buffer[buf_idx][buf_pos++] = 0;
        }
    }

    // Wait for any active transfer
    if (transfer_active) {
        if (qspi_write_end() != 0) {
            r = false;
            goto out;
        }
    }

    // Flush remaining
    if (buf_pos > 0) {
        if (qspi_write(CMD_WRITE_MEM, sdram_addr, buffer[buf_idx], buf_pos) != 0) {
            r = false;
            goto out;
        }
    }

    qsort(dirs.entries, dirs.count, sizeof(uint32_t), names_cmp);
    qsort(files.entries, files.count, sizeof(uint32_t), names_cmp);
out:
    f_closedir(&dir);
    return r;
}
