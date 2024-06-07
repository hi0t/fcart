file(GLOB SRC "fatfs/*.c")

set(SRC
    ${SRC}
    "crc.c"
    "rtc.c"
)

if(USE_SDIO)
    set(SRC ${SRC} "sdcard_sdio.c")
else()
    set(SRC ${SRC} "sdcard_spi.c")
endif()

add_library(sd INTERFACE)
target_sources(sd INTERFACE ${SRC})
target_link_libraries(sd INTERFACE
    common
    pico_stdlib
    hardware_rtc
    hardware_spi
)
target_include_directories(sd INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}
    ${CMAKE_CURRENT_LIST_DIR}/fatfs
)
