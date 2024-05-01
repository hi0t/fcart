include(AddQuartusProject)

set(FAMILY "Cyclone 10 LP" CACHE STRING "FPGA family")
set(DEVICE "10CL025YU256I7G" CACHE STRING "FPGA device")

SET(SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src")
file(GLOB_RECURSE SRC ${SRC_DIR}/*.sv)
file(GLOB_RECURSE TCL ${SRC_DIR}/*.tcl)
file(GLOB_RECURSE SDC ${SRC_DIR}/*.sdc)

add_quartus_project(${CMAKE_PROJECT_NAME})

add_custom_target(hw ALL DEPENDS quartus-compile)
