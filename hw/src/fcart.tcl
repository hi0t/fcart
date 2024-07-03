set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk
set_location_assignment PIN_E2 -to clk

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to key_in
set_location_assignment PIN_D3 -to key_in
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to key_out
set_location_assignment PIN_F9 -to key_out

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to led[*]
set_location_assignment PIN_B3 -to led[0]
set_location_assignment PIN_C3 -to led[1]
set_location_assignment PIN_B4 -to led[2]
set_location_assignment PIN_A3 -to led[3]
set_location_assignment PIN_A2 -to led[4]
set_location_assignment PIN_F8 -to led[5]
set_location_assignment PIN_E6 -to led[6]
set_location_assignment PIN_A4 -to led[7]

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk_sdio
set_location_assignment PIN_E8 -to clk_sdio
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to cmd_sdio
set_location_assignment PIN_A7 -to cmd_sdio
