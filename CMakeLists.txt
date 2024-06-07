cmake_minimum_required(VERSION 3.17...3.28)

set(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" "${CMAKE_SOURCE_DIR}/cmake")

set(PICO_SDK_FETCH_FROM_GIT on)
include(pico_sdk_import)

project(fcart)

add_subdirectory(hw)
add_subdirectory(sw)
