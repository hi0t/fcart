enable_testing()

set(TEST_TO_RUN
    sdio_tb.sv
    sdram_tb.sv
)

find_package(Questa REQUIRED)

foreach (test ${TEST_TO_RUN})
    get_filename_component(test_name ${test} NAME_WE)
    add_test(NAME ${test_name}_build COMMAND ${QUESTA_VLOG} +libext+.sv+.vp+.v -y ${CMAKE_SOURCE_DIR}/hw/src -y ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/${test})
    add_test(NAME ${test_name} COMMAND ${QUESTA_VSIM} -c -voptargs=+acc -onfinish stop -do "run -all; quit -code [coverage attribute -name TESTSTATUS -concise]" ${test_name})
    set_tests_properties(${test_name} PROPERTIES DEPENDS ${test_name}_build)
endforeach()
