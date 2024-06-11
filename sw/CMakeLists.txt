option(USE_SDIO "use SDIO connection to sdcard" OFF)
option(ENABLE_TRACE "enable USB tracing" ON)

set(PICO_BOARD_HEADER_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/lib/common )
set(PICO_BOARD board)

pico_sdk_init()

add_subdirectory(lib)
add_subdirectory(src)
add_subdirectory(util)
