#pragma once

#include <stdint.h>

struct dirlist_entry {
    char name[256];
    bool is_dir;
    uint8_t _padding[31];
} __attribute__((aligned(32)));

bool dirlist_load();
bool dirlist_push(const char *subdir);
bool dirlist_pop();
uint32_t dirlist_size();
uint8_t dirlist_select(uint32_t index, uint8_t limit, struct dirlist_entry *out);
char *dirlist_file_path(struct dirlist_entry *entry);
