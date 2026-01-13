#include "ui.h"
#include "dirlist.h"
#include "fpga_api.h"
#include "gfx.h"
#include "joypad.h"
#include "rom.h"
#include <ff.h>
#include <gpio.h>
#include <stdlib.h>
#include <string.h>

#define ROWS 30
#define COLS 32
#define FONT_WIDTH 8
#define VISIBLE_ROWS ROWS - 4

static bool on_menu;
static bool sd_mounted;
static bool usb_mode;
static FATFS fs;
static struct dirlist_entry screen_list[VISIBLE_ROWS];
static uint8_t cursor_pos;
static uint16_t dir_index;

static void show_message(const char *msg);
static void redraw_screen();
static void sd_state(bool present);
static void process_input(uint8_t buttons);
static void menu_control(uint8_t buttons);
static void game_control(uint8_t buttons);

void ui_init()
{
    set_sd_callback(sd_state);
    joypad_set_callback(process_input);
    joypad_can_repeat(BUTTON_UP | BUTTON_DOWN);
}
void ui_set_usb_mode(bool enabled)
{
    usb_mode = enabled;
    if (enabled) {
        show_message("USB Mode");
    } else {
        sd_state(is_sd_present());
    }
}

void ui_poll()
{
    bool loader_active = (fpga_api_ev_reg() & (1 << 8U)) != 0;

    if (loader_active && !on_menu) {
        on_menu = true;
        sd_state(is_sd_present());
    }

    on_menu = loader_active;
    joypad_poll();
}

static void show_message(const char *msg)
{
    if (!on_menu) {
        return;
    }

    uint16_t len = strlen(msg);

    gfx_clear();
    gfx_text((COLS - len) / 2 * FONT_WIDTH, (ROWS / 2 - 1) * FONT_WIDTH, msg, -1, 1);
    gfx_refresh();
}

static void redraw_screen()
{
    if (!on_menu || usb_mode) {
        return;
    }

    uint8_t cnt = dirlist_select(dir_index, VISIBLE_ROWS, screen_list);
    if (cnt == 0) {
        return;
    }

    gfx_clear();
    for (uint8_t i = 0; i < cnt; i++) {
        if (i == cursor_pos) {
            gfx_fill_rect(FONT_WIDTH, (i + 2) * FONT_WIDTH, (COLS - 2) * FONT_WIDTH, FONT_WIDTH, 3);
        }
        gfx_text(FONT_WIDTH, (i + 2) * FONT_WIDTH, screen_list[i].name, COLS - 2, screen_list[i].is_dir ? 2 : 1);
    }
    gfx_refresh();
}

static void sd_state(bool present)
{
    if (present) {
        if (f_mount(&fs, "/SD", 1) != FR_OK) {
            show_message("Mount error");
            return;
        }
        if (dirlist_load() != 0) {
            show_message("Open dir error");
            return;
        }
        dir_index = 0;
        cursor_pos = 0;
        redraw_screen();
    } else {
        f_unmount("/SD");
        show_message("No SD card");
    }
}

static void process_input(uint8_t buttons)
{
    if (usb_mode) {
        return;
    }

    if (on_menu) {
        menu_control(buttons);
    } else {
        game_control(buttons);
    }
}

static void menu_control(uint8_t buttons)
{
    if (buttons & BUTTON_UP) {
        if (cursor_pos == 0) {
            if (dir_index > 0) {
                dir_index--;
            }
        } else {
            cursor_pos--;
        }
    } else if (buttons & BUTTON_DOWN) {
        if (cursor_pos == VISIBLE_ROWS - 1) {
            if (dir_index + VISIBLE_ROWS < dirlist_size()) {
                dir_index++;
            }
        } else if (dir_index + cursor_pos + 1 < dirlist_size()) {
            cursor_pos++;
        }
    } else if (buttons & BUTTON_LEFT) {
        if (dir_index < VISIBLE_ROWS) {
            dir_index = 0;
            cursor_pos = 0;
        } else {
            dir_index -= VISIBLE_ROWS;
        }
    } else if (buttons & BUTTON_RIGHT) {
        if (dir_index + VISIBLE_ROWS < dirlist_size()) {
            dir_index += VISIBLE_ROWS;
        } else {
            cursor_pos = dirlist_size() - dir_index - 1;
        }
    } else if (buttons & BUTTON_A) {
        struct dirlist_entry *entry = &screen_list[cursor_pos];
        if (entry->is_dir) {
            show_message("Reading directory...");

            if (dirlist_push(entry->name) != 0) {
                show_message("Open dir error");
                return;
            }
            dir_index = 0;
            cursor_pos = 0;
        } else {
            char *full_path = dirlist_file_path(entry);
            if (full_path == NULL) {
                show_message("Memory error");
                return;
            }
            int err = rom_load(full_path);
            free(full_path);
            if (err != 0) {
                show_message("Load ROM error");
            }
            return;
        }
    } else if (buttons & BUTTON_B) {
        show_message("Reading directory...");

        if (dirlist_pop() != 0) {
            return;
        }
        dir_index = 0;
        cursor_pos = 0;
    } else {
        return;
    }
    redraw_screen();
}

static void game_control(uint8_t buttons)
{
    (void)buttons;
}
