cmake_minimum_required(VERSION 3.10)

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake-d/cmake-d)
set(CMAKE_INCLUDE_CURRENT_DIR On)
enable_testing()

project(dvm D)
add_subdirectory(src)
add_subdirectory(test)
