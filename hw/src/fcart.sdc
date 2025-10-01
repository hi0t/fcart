create_clock -name CLK_IN -period 20 [get_ports CLK_IN]
create_clock -name CLK -period 10 [get_pins pll.CLKOP]
create_clock -name SDRAM_CLK -period 10 [get_pins pll.CLKOS]
create_clock -name QSPI_CLK -period 40 [get_ports QSPI_CLK]
create_clock -name M2 -period 500 [get_ports M2]
create_clock -name PPU_RD -period 500 [get_ports PPU_RD]

set_clock_groups -exclusive \
    -group [get_clocks CLK] \
    -group [get_clocks QSPI_CLK] \
    -group [get_clocks M2] \
    -group [get_clocks PPU_RD]

set_false_path -from [get_ports QSPI_NCS]
set_false_path -to [get_ports FPGA_IRQ]
