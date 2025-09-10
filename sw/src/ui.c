#include "ui.h"
#include "fpga_api.h"
#include "gfx.h"
#include <ff.h>
#include <gpio.h>
#include <string.h>

#define ROWS 30
#define COLS 32
#define FONT_WIDTH 8

static FATFS fs;
static char screen_list[ROWS - 2][COLS - 2];
static uint8_t selected;

static void sd_state(bool present);
static void process_input();

void ui_init()
{
    set_sd_callback(sd_state);
}

void ui_poll()
{
    if (irq_called()) {
        process_input();
    }
}

static void show_error(const char *msg)
{
    uint16_t len = strlen(msg);

    gfx_clear();
    gfx_text((COLS - len) / 2 * FONT_WIDTH, (ROWS / 2 - 1) * FONT_WIDTH, msg, 1);
    gfx_refresh();
}

static void redraw_screen()
{
    gfx_clear();
    for (uint8_t i = 0; i < ROWS - 2; i++) {
        if (i == selected) {
            gfx_fill_rect(FONT_WIDTH, (i + 1) * FONT_WIDTH, (COLS - 2) * FONT_WIDTH, FONT_WIDTH, 3);
        }
        gfx_text(FONT_WIDTH, (i + 1) * FONT_WIDTH, screen_list[i], 1);
    }
    gfx_refresh();
}

static void list_dir()
{
    FRESULT res;
    DIR dir;
    FILINFO fno;

    if ((res = f_opendir(&dir, "/")) != FR_OK) {
        show_error("Open dir error");
        return;
    }

    uint8_t i = 0;
    for (;;) {
        res = f_readdir(&dir, &fno);
        if (res != FR_OK || fno.fname[0] == 0 || i >= ROWS - 2) {
            break;
        }
        if (fno.fname[0] == '.') {
            continue; // Skip hidden files
        }
        if (fno.fattrib & AM_DIR) {
        } else {
            memcpy(screen_list[i++], fno.fname, sizeof(screen_list[i++]));
        }
    }
    f_closedir(&dir);
}

static void sd_state(bool present)
{
    if (present) {
        if (f_mount(&fs, "/SD", 1) != FR_OK) {
            show_error("Mount error");
            return;
        }
        list_dir();
        selected = 0;
        redraw_screen();
    } else {
        f_unmount("/SD");
        show_error("No SD card");
    }
}

static void process_input()
{
    static uint8_t last_buttons;

    uint32_t args;
    fpga_api_read_reg(FPGA_REG_LOADER, &args);
    uint8_t buttons = args & 0xFF;

    if (buttons & 0x04) { // down
        if (selected < ROWS - 3) {
            selected++;
        }
    } else if (buttons & 0x08) { // up
        if (selected > 0) {
            selected--;
        }
    }
    redraw_screen();
}
