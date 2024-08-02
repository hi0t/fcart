derive_pll_clocks
derive_clock_uncertainty

create_clock -name "CLK" -period 20ns [get_ports {CLK}]
create_clock -name "SDIO_CLK" -period 800ns [get_ports {SDIO_CLK}]
create_clock -name "M2" -period 500ns [get_ports {M2}]
