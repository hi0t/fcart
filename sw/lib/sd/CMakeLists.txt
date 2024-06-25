file(GLOB SRC "fatfs/*.c")

set(SRC
    ${SRC}
    "rtc.c"
    "sdcard_priv.c"
)

if(SDCARD_SPI)
    set(SRC ${SRC} "sdcard_spi.c")
else()
    set(SRC ${SRC} "sdcard_sdio.c")
endif()

add_library(sd INTERFACE)
target_sources(sd INTERFACE ${SRC})
target_link_libraries(sd INTERFACE
    common
    pico_stdlib
    hardware_rtc
    hardware_spi
    sdio
)
target_include_directories(sd INTERFACE
    ${CMAKE_CURRENT_LIST_DIR}
    ${CMAKE_CURRENT_LIST_DIR}/fatfs
)
if(SDCARD_SPI)
    target_compile_definitions(sd INTERFACE SDCARD_SPI)
endif()
