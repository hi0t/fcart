load_package report

set project_name [lindex $quartus(args) 0]
project_open $project_name

load_report

set cmd get_fitter_resource_usage

set les [$cmd -le]
set pins [$cmd -io_pin]
set dsp [$cmd -resource "Embedded Multiplier 9-bit elements"]
puts stderr "Total logic elements               : $les"
puts stderr "Total pins                         : $pins"
puts stderr "Embedded Multiplier 9-bit elements : $dsp"

unload_report
project_close
