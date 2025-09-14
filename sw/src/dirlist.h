#pragma once

#include <stdbool.h>
#include <stdint.h>

struct dirlist_entry {
    char *name;
    bool is_dir;
};

bool dirlist_load();
bool dirlist_push(const char *subdir);
bool dirlist_pop();
uint32_t dirlist_size();
uint8_t dirlist_select(uint32_t index, uint8_t limit, struct dirlist_entry *out);
