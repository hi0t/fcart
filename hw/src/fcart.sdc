create_clock -name CLK_IN -period 20 [get_ports CLK_IN]
create_clock -name CLK -period 10 [get_pins pll.CLKOP]
create_clock -name SDRAM_CLK -period 10 [get_pins pll.CLKOS]
create_clock -name QSPI_CLK -period 40 [get_ports QSPI_CLK]
create_clock -name M2 -period 500 [get_ports M2]
create_clock -name PPU_RD -period 500 [get_ports PPU_RD]

set_false_path -from [get_ports QSPI_NCS]
set_false_path -to [get_ports FPGA_IRQ]

# SDRAM constraints
# Assuming ~100MHz (10ns)
# tAC = 5.5ns, tOH = 2.5ns (from datasheet for -6 speed grade)
# tIS = 1.5ns, tIH = 0.8ns

set_input_delay -clock [get_clocks SDRAM_CLK] -max 6.0 [get_ports SDRAM_DQ*]
set_input_delay -clock [get_clocks SDRAM_CLK] -min 2.0 [get_ports SDRAM_DQ*]

set_output_delay -clock [get_clocks SDRAM_CLK] -max 1.5 [get_ports {SDRAM_ADDR* SDRAM_BA* SDRAM_RAS SDRAM_CAS SDRAM_WE SDRAM_CS SDRAM_DQM* SDRAM_DQ*}]
set_output_delay -clock [get_clocks SDRAM_CLK] -min -0.8 [get_ports {SDRAM_ADDR* SDRAM_BA* SDRAM_RAS SDRAM_CAS SDRAM_WE SDRAM_CS SDRAM_DQM* SDRAM_DQ*}]
