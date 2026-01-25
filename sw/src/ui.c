#include "ui.h"
#include "dirlist.h"
#include "fpga_api.h"
#include "gfx.h"
#include "joypad.h"
#include "rom.h"
#include <ff.h>
#include <gpio.h>
#include <soc.h>
#include <stdlib.h>
#include <string.h>

#define ROWS 30
#define COLS 32
#define FONT_WIDTH 8
#define VISIBLE_ROWS ROWS - 4

enum ui_state {
    UI_STATE_IDLE,
    UI_STATE_RESET,
    UI_STATE_MENU,
    UI_STATE_GAME,
    UI_STATE_REQ_PAUSE,
    UI_STATE_PAUSE,
};

static FATFS fs;
static struct dirlist_entry screen_list[VISIBLE_ROWS];
static uint8_t screen_list_cnt;
static enum ui_state state;
static uint8_t cursor_pos;
static uint8_t ingame_cursor;
static uint16_t dir_index;

static void update_screen_list()
{
    screen_list_cnt = dirlist_select(dir_index, VISIBLE_ROWS, screen_list);
}

static inline bool launcher_active()
{
    return (fpga_api_ev_reg() & (1U << 8)) != 0;
}
static inline bool console_reset()
{
    return (fpga_api_ev_reg() & (1U << 9)) != 0;
}
static void show_message(const char *msg);
static void redraw_screen();
static void sd_state(bool present);
static void process_input(uint8_t pressed, uint8_t current);

void ui_init()
{
    set_sd_callback(sd_state);
    joypad_can_repeat(BUTTON_UP | BUTTON_DOWN);
}

void ui_poll()
{
    bool is_active = launcher_active();

    if (console_reset()) {
        state = UI_STATE_RESET;
        return;
    }

    switch (state) {
    case UI_STATE_IDLE:
    case UI_STATE_RESET:
        if (is_active) {
            rom_save_battery();
            state = UI_STATE_MENU;
            sd_state(is_sd_present());
        }
        break;
    case UI_STATE_REQ_PAUSE:
        if (is_active) {
            rom_save_battery();
            state = UI_STATE_PAUSE;
            ingame_cursor = 0;
            redraw_screen();
        }
        break;
    case UI_STATE_GAME:
        // Return to menu if we skipped reset while in game
        /*if (is_active) {
            state = UI_STATE_RESET;
        }*/
        break;
    default:
    }

    uint8_t current;
    uint8_t pressed = joypad_poll(&current);
    if (pressed || current) {
        process_input(pressed, current);
    }
}

bool ui_is_active()
{
    return state != UI_STATE_IDLE;
}

static void show_message(const char *msg)
{
    if (!launcher_active()) {
        return;
    }

    uint16_t len = strlen(msg);
    uint16_t w_chars = len + 2;
    uint16_t h_chars = 3;

    int box_x = (COLS - w_chars) / 2 * FONT_WIDTH;
    int box_y = (ROWS - h_chars) / 2 * FONT_WIDTH;
    int box_w = w_chars * FONT_WIDTH;
    int box_h = h_chars * FONT_WIDTH;

    gfx_clear();

    gfx_line(box_x, box_y, box_x + box_w, box_y, 1);
    gfx_line(box_x, box_y + box_h, box_x + box_w, box_y + box_h, 1);
    gfx_line(box_x, box_y, box_x, box_y + box_h, 1);
    gfx_line(box_x + box_w, box_y, box_x + box_w, box_y + box_h, 1);

    gfx_text((COLS - len) / 2 * FONT_WIDTH, (ROWS / 2 - 1) * FONT_WIDTH, msg, -1, 1);
    gfx_refresh();
}

static void draw_main_menu()
{
    uint8_t cnt = screen_list_cnt;
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

static void draw_pause_menu()
{
    gfx_clear();

    const int w_chars = 14;
    const int h_chars = 8;
    int box_x = (COLS - w_chars) / 2 * FONT_WIDTH;
    int box_y = (ROWS - h_chars) / 2 * FONT_WIDTH;
    int box_w = w_chars * FONT_WIDTH;
    int box_h = h_chars * FONT_WIDTH;

    // Frame
    gfx_line(box_x, box_y, box_x + box_w, box_y, 1);
    gfx_line(box_x, box_y + box_h, box_x + box_w, box_y + box_h, 1);
    gfx_line(box_x, box_y, box_x, box_y + box_h, 1);
    gfx_line(box_x + box_w, box_y, box_x + box_w, box_y + box_h, 1);

    // Title
    const char *title = "PAUSE";
    int title_len = strlen(title);
    gfx_text(box_x + (box_w - title_len * FONT_WIDTH) / 2, box_y + FONT_WIDTH, title, -1, 1);

    // Items
    const char *items[] = { "Continue", "Save State", "Reset" };
    for (int i = 0; i < 3; i++) {
        int y = box_y + (3 + i) * FONT_WIDTH;
        if (i == ingame_cursor) {
            gfx_fill_rect(box_x + 4, y, box_w - 8, FONT_WIDTH, 3);
        }
        int item_len = strlen(items[i]);
        gfx_text(box_x + (box_w - item_len * FONT_WIDTH) / 2, y, items[i], -1, 1);
    }
    gfx_refresh();
}

static void redraw_screen()
{
    switch (state) {
    case UI_STATE_MENU:
        draw_main_menu();
        break;
    case UI_STATE_PAUSE:
        draw_pause_menu();
        break;
    default:
    }
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
        update_screen_list();
        redraw_screen();
    } else {
        f_unmount("/SD");
        show_message("No SD card");
    }
}

static void menu_control(uint8_t buttons)
{
    uint16_t prev_dir_index = dir_index;

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
            update_screen_list();
            prev_dir_index = dir_index;
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
                return;
            }
            uint32_t start = uptime_ms();
            while (launcher_active()) {
                if (uptime_ms() - start > 10000) {
                    show_message("Launch timeout");
                    return;
                }
            }
            state = UI_STATE_GAME;
            return;
        }
    } else if (buttons & BUTTON_B) {
        show_message("Reading directory...");

        if (dirlist_pop() != 0) {
            return;
        }
        dir_index = 0;
        cursor_pos = 0;
        update_screen_list();
        prev_dir_index = dir_index;
    } else {
        return;
    }

    if (dir_index != prev_dir_index) {
        update_screen_list();
    }
    redraw_screen();
}

static void pause_control(uint8_t buttons)
{
    if (buttons & BUTTON_UP) {
        if (ingame_cursor > 0) {
            ingame_cursor--;
        }
    } else if (buttons & BUTTON_DOWN) {
        if (ingame_cursor < 2) {
            ingame_cursor++;
        }
    } else if (buttons & BUTTON_A) {
        if (ingame_cursor == 0) {
            rom_select_current_app();
            fpga_api_write_reg(FPGA_REG_LAUNCHER, 1U << 2); // request resume
            state = UI_STATE_GAME;
        } else if (ingame_cursor == 1) {
            show_message("Saving...");
            rom_save_state();
        } else if (ingame_cursor == 2) {
            state = UI_STATE_RESET;
        }
    } else {
        return;
    }
    redraw_screen();
}

static void process_input(uint8_t pressed, uint8_t current)
{
    if (state == UI_STATE_GAME) {
        if ((current & (BUTTON_SELECT | BUTTON_DOWN)) == (BUTTON_SELECT | BUTTON_DOWN)) {
            rom_select_launcher();
            fpga_api_write_reg(FPGA_REG_LAUNCHER, 1U << 3); // request pause
            state = UI_STATE_REQ_PAUSE;
        }
    } else if (state == UI_STATE_PAUSE) {
        pause_control(pressed);
    } else if (state == UI_STATE_MENU) {
        menu_control(pressed);
    }
}
