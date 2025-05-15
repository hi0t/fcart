create_clock -name CLK_IN -period 20 [get_ports CLK_IN]
create_clock -name CLK -period 20 [get_ports pll.CLKOP]
create_clock -name SDRAM_CLK -period 10 [get_pins pll.CLKOS]
create_clock -name QSPI_CLK -period 20 [get_ports QSPI_CLK]
create_clock -name M2 -period 500 [get_ports M2]

set_clock_groups -exclusive \
    -group [get_clocks {CLK}] \
    -group [get_clocks {QSPI_CLK}]
