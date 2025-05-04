derive_pll_clocks
derive_clock_uncertainty

create_clock -name "CLK" -period "50.0 MHz" [get_ports {CLK}]
create_clock -name "SPI_SCK" -period "50.0 MHz" [get_ports {SPI_SCK}]
create_clock -name "M2" -period "2.0 MHz" [get_ports {M2}]
create_clock -name "ROMSEL" -period "2.0 MHz" [get_ports {ROMSEL}]
create_clock -name "PPU_RD" -period "2.0 MHz" [get_ports {PPU_RD}]

set_clock_groups -exclusive \
    -group [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] \
    -group [get_clocks {CLK}] \
    -group [get_clocks {SPI_SCK}] \
    -group [get_clocks {M2}] \
    -group [get_clocks {ROMSEL}] \
    -group [get_clocks {PPU_RD}]
