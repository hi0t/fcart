include(AddQuartusProject)

set(FAMILY "Cyclone 10 LP" CACHE STRING "FPGA family")
set(DEVICE "10CL025YU256I7G" CACHE STRING "FPGA device")

file(GLOB_RECURSE SRC *.sv ip/*.v)
file(GLOB_RECURSE TCL *.tcl)
file(GLOB_RECURSE SDC *.sdc)

add_quartus_project(${CMAKE_PROJECT_NAME})

file(RELATIVE_PATH cof_path ${QUARTUS_PROJECT_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/fcart.cof)

add_custom_command(
    OUTPUT ${QUARTUS_PROJECT_DIR}/fcart.jic
    DEPENDS ${QUARTUS_PROJECT_DIR}/fcart.sof
    COMMAND ${QUARTUS_CPF} -c ${cof_path}
    WORKING_DIRECTORY ${QUARTUS_PROJECT_DIR}
)

add_custom_command(
    OUTPUT ${QUARTUS_PROJECT_DIR}/fcart.svf
    DEPENDS ${QUARTUS_PROJECT_DIR}/fcart.jic
    COMMAND ${QUARTUS_CPF} -c -q 33MHz -g 3.3 -n p fcart.jic fcart.svf
    WORKING_DIRECTORY ${QUARTUS_PROJECT_DIR}
)

add_custom_target(serial-flash ALL DEPENDS ${QUARTUS_PROJECT_DIR}/fcart.svf)
