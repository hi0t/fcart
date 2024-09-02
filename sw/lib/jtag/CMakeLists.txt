file(GLOB SRC "*.c")

add_library(jtag INTERFACE)

pico_generate_pio_header(jtag ${CMAKE_CURRENT_SOURCE_DIR}/jtag.pio)

target_sources(jtag INTERFACE ${SRC})
target_link_libraries(jtag INTERFACE
    hardware_dma
    hardware_pio
)
target_include_directories(jtag INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
