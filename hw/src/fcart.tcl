set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED WITH WEAK PULL-UP"
set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLK
set_location_assignment PIN_E2 -to CLK

# SDIO interface
set_location_assignment PIN_E8 -to SDIO_CLK
set_location_assignment PIN_A7 -to SDIO_CMD

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDIO_*

# SDRAM interface
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
set_location_assignment PIN_N8 -to SDRAM_BA[0]
set_location_assignment PIN_L8 -to SDRAM_BA[1]
set_location_assignment PIN_P2 -to SDRAM_CLK
set_location_assignment PIN_R1 -to SDRAM_CKE
set_location_assignment PIN_P8 -to SDRAM_CS
set_location_assignment PIN_M8 -to SDRAM_RAS
set_location_assignment PIN_M7 -to SDRAM_CAS
set_location_assignment PIN_P6 -to SDRAM_WE
set_location_assignment PIN_N6 -to SDRAM_DQM[0]
set_location_assignment PIN_P1 -to SDRAM_DQM[1]

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_*

# cart interface
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to M2
set_location_assignment PIN_N14 -to M2
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CPU_ADDR[*]
set_location_assignment PIN_P14 -to CPU_ADDR[0]
set_location_assignment PIN_T15 -to CPU_ADDR[1]
set_location_assignment PIN_T14 -to CPU_ADDR[2]
set_location_assignment PIN_T13 -to CPU_ADDR[3]
set_location_assignment PIN_N11 -to CPU_ADDR[4]
set_location_assignment PIN_N12 -to CPU_ADDR[5]
set_location_assignment PIN_R14 -to CPU_ADDR[6]
set_location_assignment PIN_R13 -to CPU_ADDR[7]
set_location_assignment PIN_P11 -to CPU_ADDR[8]
set_location_assignment PIN_M10 -to CPU_ADDR[9]
set_location_assignment PIN_R12 -to CPU_ADDR[10]
set_location_assignment PIN_R11 -to CPU_ADDR[11]
set_location_assignment PIN_T11 -to CPU_ADDR[12]
set_location_assignment PIN_T12 -to CPU_ADDR[13]
set_location_assignment PIN_P9 -to CPU_ADDR[14]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CPU_DATA[*]
set_location_assignment PIN_C16 -to CPU_DATA[0]
set_location_assignment PIN_C15 -to CPU_DATA[1]
set_location_assignment PIN_D15 -to CPU_DATA[2]
set_location_assignment PIN_D16 -to CPU_DATA[3]
set_location_assignment PIN_F16 -to CPU_DATA[4]
set_location_assignment PIN_F15 -to CPU_DATA[5]
set_location_assignment PIN_G16 -to CPU_DATA[6]
set_location_assignment PIN_G15 -to CPU_DATA[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CPU_RW
set_location_assignment PIN_B16 -to CPU_RW
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ROM_CE
set_location_assignment PIN_A15 -to ROM_CE
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to PPU_RD
set_location_assignment PIN_D14 -to PPU_RD
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CIRAM_A10
set_location_assignment PIN_F14 -to CIRAM_A10
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CIRAM_CE
set_location_assignment PIN_D12 -to CIRAM_CE
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to PPU_ADDR[*]
set_location_assignment PIN_J14 -to PPU_ADDR[0]
set_location_assignment PIN_K16 -to PPU_ADDR[1]
set_location_assignment PIN_L14 -to PPU_ADDR[2]
set_location_assignment PIN_L16 -to PPU_ADDR[3]
set_location_assignment PIN_L15 -to PPU_ADDR[4]
set_location_assignment PIN_N15 -to PPU_ADDR[5]
set_location_assignment PIN_P15 -to PPU_ADDR[6]
set_location_assignment PIN_R16 -to PPU_ADDR[7]
set_location_assignment PIN_P16 -to PPU_ADDR[8]
set_location_assignment PIN_N16 -to PPU_ADDR[9]
set_location_assignment PIN_L13 -to PPU_ADDR[10]
set_location_assignment PIN_K15 -to PPU_ADDR[11]
set_location_assignment PIN_J13 -to PPU_ADDR[12]
set_location_assignment PIN_J16 -to PPU_ADDR[13]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to PPU_DATA[*]
set_location_assignment PIN_B14 -to PPU_DATA[0]
set_location_assignment PIN_B13 -to PPU_DATA[1]
set_location_assignment PIN_B12 -to PPU_DATA[2]
set_location_assignment PIN_B11 -to PPU_DATA[3]
set_location_assignment PIN_A11 -to PPU_DATA[4]
set_location_assignment PIN_A12 -to PPU_DATA[5]
set_location_assignment PIN_A13 -to PPU_DATA[6]
set_location_assignment PIN_A14 -to PPU_DATA[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CPU_DIR
set_location_assignment PIN_G1 -to CPU_DIR
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to PPU_DIR
set_location_assignment PIN_G2 -to PPU_DIR
