cmake_minimum_required(VERSION 3.17...3.28)

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_ASM_COMPILER cl65)
set(CMAKE_ASM_COMPILER_ID ca65)

project(nesrom)

enable_language(ASM)

add_executable(nesrom.bin main.s)
set_target_properties(nesrom.bin PROPERTIES
    COMPILE_FLAGS "-t nes"
    LINK_FLAGS "-C ${CMAKE_CURRENT_SOURCE_DIR}/nes.cfg"
    LINK_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/nes.cfg"
)

add_custom_command(
    TARGET nesrom.bin
    POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} ARGS -I binary -O verilog nesrom.bin nesrom.hex
)
