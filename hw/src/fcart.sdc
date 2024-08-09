derive_pll_clocks
derive_clock_uncertainty

create_clock -name "CLK" -period "50.0 MHz" [get_ports {CLK}]
create_clock -name "SDIO_CLK" -period "1.25 MHz" [get_ports {SDIO_CLK}]
create_clock -name "M2" -period "2.0 MHz" [get_ports {M2}]

set_clock_groups -asynchronous \
    -group [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] \
    -group [get_clocks {SDIO_CLK}] \
    -group [get_clocks {M2}]

set_multicycle_path -from {sdram:ram|*} -to [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -start -setup 2
set_multicycle_path -from {sdram:ram|*} -to [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -start -hold 1
set_multicycle_path -from [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -to {sdram:ram|*} -setup 2
set_multicycle_path -from [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -to {sdram:ram|*} -hold 1

#set_multicycle_path -from [get_ports {PPU_ADDR[*] PPU_RD}] -to [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -start -setup 2
#set_multicycle_path -from [get_ports {PPU_ADDR[*] PPU_RD}] -to [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -start -hold 1
#set_multicycle_path -from [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -to [get_ports {PPU_DATA[*]}] -setup 2
#set_multicycle_path -from [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -to [get_ports {PPU_DATA[*]}] -hold 1

#set_max_delay -from [get_ports {CPU_ADDR[*]}] -to {mux8bit*} 1
#set_max_delay -from {mux8bit*} -to [get_ports {CPU_DATA[*]}] 1
#set_max_delay -from [get_ports {CPU_RW}] -to {mux8bit*} 1
#set_max_delay -from [get_ports {ROM_CE}] -to {mux8bit*} 1
#set_max_delay -from [get_ports {PPU_RD}] -to {mux8bit*} 1
#set_max_delay -from [get_ports {PPU_ADDR[*]}] -to {mux8bit*} 1
#set_max_delay -from {mux8bit*} -to [get_ports {PPU_DATA[*]}] 1

