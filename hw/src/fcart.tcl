set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED WITH WEAK PULL-UP"

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLK
set_location_assignment PIN_B8 -to CLK

#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to key_in
#set_location_assignment PIN_D3 -to key_in
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to key_out
#set_location_assignment PIN_F9 -to key_out

#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to led[*]
#set_location_assignment PIN_B3 -to led[0]
#set_location_assignment PIN_C3 -to led[1]
#set_location_assignment PIN_B4 -to led[2]
#set_location_assignment PIN_A3 -to led[3]
#set_location_assignment PIN_A2 -to led[4]
#set_location_assignment PIN_F8 -to led[5]
#set_location_assignment PIN_E6 -to led[6]
#set_location_assignment PIN_A4 -to led[7]

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDIO_CLK
set_location_assignment PIN_E8 -to SDIO_CLK
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDIO_CMD
set_location_assignment PIN_A7 -to SDIO_CMD

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[*]
set_location_assignment PIN_K5 -to SDRAM_DQ[0]
set_location_assignment PIN_L3 -to SDRAM_DQ[1]
set_location_assignment PIN_L4 -to SDRAM_DQ[2]
set_location_assignment PIN_L7 -to SDRAM_DQ[3]
set_location_assignment PIN_N3 -to SDRAM_DQ[4]
set_location_assignment PIN_M6 -to SDRAM_DQ[5]
set_location_assignment PIN_P3 -to SDRAM_DQ[6]
set_location_assignment PIN_N5 -to SDRAM_DQ[7]
set_location_assignment PIN_N2 -to SDRAM_DQ[8]
set_location_assignment PIN_N1 -to SDRAM_DQ[9]
set_location_assignment PIN_L1 -to SDRAM_DQ[10]
set_location_assignment PIN_L2 -to SDRAM_DQ[11]
set_location_assignment PIN_K1 -to SDRAM_DQ[12]
set_location_assignment PIN_K2 -to SDRAM_DQ[13]
set_location_assignment PIN_J1 -to SDRAM_DQ[14]
set_location_assignment PIN_J2 -to SDRAM_DQ[15]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[*]
set_location_assignment PIN_R7 -to SDRAM_ADDR[0]
set_location_assignment PIN_T7 -to SDRAM_ADDR[1]
set_location_assignment PIN_T10 -to SDRAM_ADDR[2]
set_location_assignment PIN_R10 -to SDRAM_ADDR[3]
set_location_assignment PIN_R6 -to SDRAM_ADDR[4]
set_location_assignment PIN_T5 -to SDRAM_ADDR[5]
set_location_assignment PIN_R5 -to SDRAM_ADDR[6]
set_location_assignment PIN_T4 -to SDRAM_ADDR[7]
set_location_assignment PIN_R4 -to SDRAM_ADDR[8]
set_location_assignment PIN_T3 -to SDRAM_ADDR[9]
set_location_assignment PIN_T6 -to SDRAM_ADDR[10]
set_location_assignment PIN_R3 -to SDRAM_ADDR[11]
set_location_assignment PIN_T2 -to SDRAM_ADDR[12]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_BA[*]
set_location_assignment PIN_N8 -to SDRAM_BA[0]
set_location_assignment PIN_L8 -to SDRAM_BA[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_CLK
set_location_assignment PIN_P2 -to SDRAM_CLK
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_CKE
set_location_assignment PIN_R1 -to SDRAM_CKE
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_CS
set_location_assignment PIN_P8 -to SDRAM_CS
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_RAS
set_location_assignment PIN_M8 -to SDRAM_RAS
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_CAS
set_location_assignment PIN_M7 -to SDRAM_CAS
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_WE
set_location_assignment PIN_P6 -to SDRAM_WE
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQM[*]
set_location_assignment PIN_N6 -to SDRAM_DQM[0]
set_location_assignment PIN_P1 -to SDRAM_DQM[1]
