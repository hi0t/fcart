option(USE_SDIO "use SDIO connection to sdcard" OFF)
option(ENABLE_TRACE "enable USB tracing" ON)

pico_sdk_init()

add_subdirectory(lib)
add_subdirectory(src)
add_subdirectory(util)
