cmake_minimum_required(VERSION 3.20.0)
include(FetchContent)

set(BUILD_VERSION 3.7.1)
set(HAL_STM32_COMMIT f1317150eac951fdd8259337a47cbbc4c2e6d335)
set(CMSIS_COMMIT 4b96cbb174678dcd3ca86e11e1f24bc5f8726da0)
set(FATFS_COMMIT 427159bf95ea49b7680facffaa29ad506b42709b)
set(BOARD_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
set(BOARD fcart)

set(NO_BUILD_TYPE_WARNING TRUE)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(CONFIG_DEBUG y CACHE INTERNAL "Enable debug")
else()
    set(CONFIG_DEBUG n CACHE INTERNAL "Disable debug")
endif()

FetchContent_Declare(
    zephyr_distro
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    URL https://github.com/zephyrproject-rtos/zephyr/archive/refs/tags/v${BUILD_VERSION}.tar.gz
    SOURCE_SUBDIR cmake # prevent cmake from being called inside the project
)
FetchContent_MakeAvailable(zephyr_distro)
FetchContent_Declare(
    hal_stm32
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    URL https://github.com/zephyrproject-rtos/hal_stm32/archive/${HAL_STM32_COMMIT}.tar.gz
    SOURCE_SUBDIR cmake
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/modules/hal/stm32"
)
FetchContent_MakeAvailable(hal_stm32)
FetchContent_Declare(
    cmsis
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    URL https://github.com/zephyrproject-rtos/cmsis/archive/${CMSIS_COMMIT}.tar.gz
    SOURCE_SUBDIR cmake
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/modules/hal/cmsis"
)
FetchContent_MakeAvailable(cmsis)
FetchContent_Declare(
    fatfs
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    URL https://github.com/zephyrproject-rtos/fatfs/archive/${FATFS_COMMIT}.tar.gz
    SOURCE_SUBDIR cmake
    SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/modules/hal/fatfs"
)
FetchContent_MakeAvailable(fatfs)
set(ZEPHYR_MODULES ${hal_stm32_SOURCE_DIR} ${cmsis_SOURCE_DIR} ${fatfs_SOURCE_DIR})

find_package(Zephyr REQUIRED HINTS ${zephyr_distro_SOURCE_DIR})

project(fcart_sw)

add_subdirectory(src)
