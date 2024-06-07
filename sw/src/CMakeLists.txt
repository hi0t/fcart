file(GLOB SRC "*.c")

add_executable(fcart ${SRC})

target_link_libraries(fcart sd pico_stdlib)
target_compile_options(fcart PUBLIC -Wall)

if(ENABLE_TRACE)
    pico_enable_stdio_uart(fcart 1)
    target_compile_definitions(fcart PUBLIC ENABLE_TRACE)
endif()

pico_add_uf2_output(fcart)
