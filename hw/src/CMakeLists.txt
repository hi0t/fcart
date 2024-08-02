include(AddQuartusProject)

set(FAMILY "Cyclone 10 LP" CACHE STRING "FPGA family")
set(DEVICE "10CL025YU256I7G" CACHE STRING "FPGA device")

file(GLOB_RECURSE SRC *.sv ip/*.v)
file(GLOB_RECURSE TCL *.tcl)
file(GLOB_RECURSE SDC *.sdc)

add_quartus_project(${CMAKE_PROJECT_NAME})

add_custom_target(hw ALL DEPENDS quartus-compile)
