add_executable(sd_speed_test "sd_speed_test.c")
target_link_libraries(sd_speed_test sd pico_stdlib)
target_compile_options(sd_speed_test PUBLIC -Wall)

pico_enable_stdio_usb(sd_speed_test 1)
pico_add_uf2_output(sd_speed_test)
