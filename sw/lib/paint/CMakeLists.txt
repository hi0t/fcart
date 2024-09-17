file(GLOB SRC "*.c")

add_library(paint INTERFACE)

target_include_directories(paint INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
