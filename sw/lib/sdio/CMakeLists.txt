file(GLOB SRC "*.c")

add_library(sdio INTERFACE)

pico_generate_pio_header(sdio ${CMAKE_CURRENT_SOURCE_DIR}/sdio.pio)

target_sources(sdio INTERFACE ${SRC})
target_link_libraries(sdio INTERFACE
    common
    hardware_dma
    hardware_pio
)
target_include_directories(sdio INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
