#pragma once

#include <stdint.h>

struct dirlist_entry {
    char name[256];
    bool is_dir;
    uint8_t _padding[31];
} __attribute__((aligned(32)));

int dirlist_load();
int dirlist_push(const char *subdir);
int dirlist_pop();
uint16_t dirlist_size();
uint8_t dirlist_select(uint16_t index, uint8_t limit, struct dirlist_entry *out);
char *dirlist_file_path(struct dirlist_entry *entry);
