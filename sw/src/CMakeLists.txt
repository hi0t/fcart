set(ZLIB_BUILD_EXAMPLES OFF)
include(FetchContent)
FetchContent_Declare(
    zlib
    URL "https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz"
    EXCLUDE_FROM_ALL
)
FetchContent_MakeAvailable(zlib)
target_compile_definitions(zlibstatic PUBLIC ZLIB_CONST)

set(SRC
    "fpga.c"
    "main.c"
    "rom.c"
)

if(ENABLE_FPGA_FLASH)
    set(SRC ${SRC} "fpga_flash.c")
endif()

add_executable(fcart ${SRC})

target_link_libraries(fcart
    sd
    sdio
    pico_stdlib
    pico_multicore
    zlibstatic
    jtag
)

if(ENABLE_FPGA_FLASH)
    set(LOADER_ARCHIVE_PATH ${CMAKE_BINARY_DIR}/quartus/loader/loader.rbf.gz)
    add_dependencies(fcart loader-archive)

    set(FCART_ARCHIVE_PATH ${CMAKE_BINARY_DIR}/quartus/fcart/fcart.rbf.gz)
    add_dependencies(fcart fcart-archive)

    target_compile_definitions(fcart
        PRIVATE LOADER_ARCHIVE_PATH="${LOADER_ARCHIVE_PATH}"
        PRIVATE FCART_ARCHIVE_PATH="${FCART_ARCHIVE_PATH}"
        ENABLE_FPGA_FLASH
    )
    set_source_files_properties(fpga_flash.c
        OBJECT_DEPENDS ${LOADER_ARCHIVE_PATH}
        OBJECT_DEPENDS ${FCART_ARCHIVE_PATH}
    )
endif()

if(ENABLE_TRACE)
    #pico_enable_stdio_usb(fcart 1)
    pico_enable_stdio_uart(fcart 1)
    target_compile_definitions(fcart PUBLIC ENABLE_TRACE)
endif()

pico_add_uf2_output(fcart)
