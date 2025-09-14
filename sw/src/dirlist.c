#include "dirlist.h"
#include <ff.h>
#include <stdlib.h>
#include <string.h>

static uint32_t *dirs;
static uint32_t dirs_capacity;
static uint32_t dirs_count;
static uint32_t *files;
static uint32_t files_capacity;
static uint32_t files_count;
static char *names;
static uint32_t names_capacity;
static char *curr_path;

static int names_cmp(const void *a, const void *b);
static bool readdir();

bool dirlist_load()
{
    if (dirs != NULL) {
        free(dirs);
    }
    dirs = malloc(32 * sizeof(uint32_t));
    dirs_capacity = 32;

    if (files != NULL) {
        free(files);
    }
    files = malloc(256 * sizeof(uint32_t));
    files_capacity = 256;

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
    return dirs_count + files_count;
}

uint8_t dirlist_select(uint32_t index, uint8_t limit, struct dirlist_entry *out)
{
    if (index >= dirs_count + files_count) {
        return 0; // Index out of bounds
    }

    uint8_t count = 0;
    uint32_t curr_index = index;

    while ((count < limit) && (curr_index < dirs_count + files_count)) {
        if (curr_index < dirs_count) {
            // Directory
            out[count].name = &names[dirs[curr_index]];
            out[count].is_dir = true;
        } else {
            // File
            out[count].name = &names[files[curr_index - dirs_count]];
            out[count].is_dir = false;
        }
        count++;
        curr_index++;
    }

    return count; // Return number of entries filled
}

static int names_cmp(const void *a, const void *b)
{
    uint32_t offset_a = *(const uint32_t *)a;
    uint32_t offset_b = *(const uint32_t *)b;
    return strcmp(&names[offset_a], &names[offset_b]);
}

static bool readdir()
{
    DIR dir;
    FILINFO fno;
    bool r = true;

    if (f_opendir(&dir, curr_path) != FR_OK) {
        return false;
    }

    dirs_count = 0;
    files_count = 0;
    uint32_t name_offset = 0;
    for (;;) {
        if (f_readdir(&dir, &fno) != FR_OK || fno.fname[0] == 0) {
            break;
        }
        if (fno.fname[0] == '.' || (fno.fattrib & AM_HID) || (fno.fattrib & AM_SYS)) {
            continue; // Skip hidden files
        }
        uint8_t name_len = strlen(fno.fname);

        // Check if we need to expand the names buffer
        if (name_offset + name_len + 1 > names_capacity) {
            char *new_names = realloc(names, names_capacity + 8192);
            if (new_names == NULL) {
                r = false;
                goto out;
            }
            names = new_names;
            names_capacity += 8192;
        }

        // Copy name to shared buffer
        memcpy(&names[name_offset], fno.fname, name_len + 1);

        if (fno.fattrib & AM_DIR) {
            // Handle directory
            if (dirs_count >= dirs_capacity) {
                uint32_t *new_dirs = realloc(dirs, dirs_capacity * 2 * sizeof(uint32_t));
                if (new_dirs == NULL) {
                    r = false;
                    goto out;
                }
                dirs = new_dirs;
                dirs_capacity *= 2;
            }
            dirs[dirs_count] = name_offset;
            dirs_count++;
        } else {
            // Handle file
            if (files_count >= files_capacity) {
                uint32_t *new_files = realloc(files, files_capacity * 2 * sizeof(uint32_t));
                if (new_files == NULL) {
                    r = false;
                    goto out;
                }
                files = new_files;
                files_capacity *= 2;
            }
            files[files_count] = name_offset;
            files_count++;
        }

        name_offset += name_len + 1;
    }

    qsort(dirs, dirs_count, sizeof(uint32_t), names_cmp);
    qsort(files, files_count, sizeof(uint32_t), names_cmp);
out:
    f_closedir(&dir);
    return r;
}
