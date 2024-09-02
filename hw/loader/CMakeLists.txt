include(AddQuartusProject)

set(FAMILY "Cyclone 10 LP" CACHE STRING "FPGA family")
set(DEVICE "10CL025YU256I7G" CACHE STRING "FPGA device")

file(GLOB_RECURSE SRC *.sv)
file(GLOB_RECURSE TCL *.tcl)
file(GLOB_RECURSE SDC *.sdc)

add_quartus_project(loader)

add_custom_command(
    OUTPUT ${QUARTUS_PROJECT_DIR}/loader.rbf.gz
    COMMAND gzip -c loader.rbf > loader.rbf.gz
    DEPENDS ${QUARTUS_PROJECT_DIR}/loader.sof
    WORKING_DIRECTORY ${QUARTUS_PROJECT_DIR}
)
add_custom_target(loader-archive ALL DEPENDS ${QUARTUS_PROJECT_DIR}/loader.rbf.gz)
