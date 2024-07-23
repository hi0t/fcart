enable_testing()

set(TEST_TO_RUN
    sdio_tb.sv
    sdram_tb.sv
)

foreach (test ${TEST_TO_RUN})
    get_filename_component(test_name ${test} NAME_WE)
    add_test(NAME ${test_name}_build COMMAND iverilog -g2012 -Y .sv -y ${CMAKE_SOURCE_DIR}/hw/src -y ${CMAKE_CURRENT_SOURCE_DIR} -o ${test_name} ${CMAKE_CURRENT_SOURCE_DIR}/${test})
    add_test(NAME ${test_name} COMMAND vvp ${test_name})
    set_tests_properties(${test_name} PROPERTIES DEPENDS ${test_name}_build)
endforeach()
