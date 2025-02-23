set project_name [lindex $quartus(args) 0]
project_open $project_name

create_timing_netlist

set domain_list [get_clock_fmax_info]
foreach domain $domain_list {
	set name [lindex $domain 0]
	set fmax [lindex $domain 1]
	set restricted_fmax [lindex $domain 2]

	puts stderr "Clock $name : Fmax = $fmax (Restricted Fmax = $restricted_fmax)"
}

delete_timing_netlist

project_close
