#pragma once

int rom_load(const char *filename);
int rom_save_battery();
int rom_save_state();
void rom_select_launcher();
void rom_select_current_app();
