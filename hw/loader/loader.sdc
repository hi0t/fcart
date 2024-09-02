derive_pll_clocks
derive_clock_uncertainty

create_clock -name "altera_reserved_tck" -period 64ns [get_ports {altera_reserved_tck}]
