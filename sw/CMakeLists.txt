option(SDCARD_SPI "use SPI connection to sdcard" OFF)
option(ENABLE_TRACE "enable USB tracing" ON)
option(ENABLE_FPGA_FLASH "flash fpga from mcu" OFF)

add_compile_options(-Wall -Werror)

set(PICO_BOARD_HEADER_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/lib/common )
set(PICO_BOARD board)

pico_sdk_init()

add_subdirectory(lib)
add_subdirectory(src)
add_subdirectory(util)
