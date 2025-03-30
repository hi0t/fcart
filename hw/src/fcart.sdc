create_clock -name CLK_IN -period 20 [get_ports CLK_IN]
create_clock -name M2 -period 500 [get_ports M2]
create_clock -name PPU_RD -period 300 [get_ports PPU_RD]
create_clock -name QSPI_CLK -period 40 [get_ports QSPI_CLK]
create_clock -name CLK -period 20 [get_pins pll.CLKOP]
create_clock -name SDRAM_CLK -period 7.5 [get_pins pll.CLKOS]
create_clock -name SDRAM_CLK_OUT -period 7.5 [get_pins pll.CLKOS2]

set_multicycle_path -to [get_clocks SDRAM_CLK] -setup 2

#set_multicycle_path -from [get_cells sdram] -to [get_clocks SDRAM_CLK] -start -setup 2
#set_multicycle_path -from [get_cells sdram] -to [get_clocks SDRAM_CLK] -start -hold 1
#set_multicycle_path -from [get_clocks SDRAM_CLK] -to [get_cells sdram] -setup 2
#set_multicycle_path -from [get_clocks SDRAM_CLK] -to [get_cells sdram] -hold 1

#set_input_delay -clock SDRAM_CLK -min 3.2 [get_ports {SDRAM_DQ[*]}]
#set_input_delay -clock SDRAM_CLK -max 5.8 [get_ports {SDRAM_DQ[*]}]

#set_output_delay -clock SDRAM_CLK -min 0.8 [get_ports SDRAM_CS {SDRAM_ADDR[*]} SDRAM_BA SDRAM_RAS SDRAM_CAS SDRAM_WE {SDRAM_DQM[*]}]
#set_output_delay -clock SDRAM_CLK -max 1.5 [get_ports SDRAM_CS {SDRAM_ADDR[*]} SDRAM_BA SDRAM_RAS SDRAM_CAS SDRAM_WE {SDRAM_DQM[*]}]
#set_output_delay -clock SDRAM_CLK -min 0.8 [get_ports {SDRAM_DQ[*]}]
#set_output_delay -clock SDRAM_CLK -max 1.5 [get_ports {SDRAM_DQ[*]}]
