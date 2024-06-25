file(GLOB SRC "*.c")
add_library(common INTERFACE)
target_sources(common INTERFACE ${SRC})
target_include_directories(common INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
