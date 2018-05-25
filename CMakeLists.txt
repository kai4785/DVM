cmake_minimum_required(VERSION 3.10)

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake-d/cmake-d)
enable_testing()

project(dvm D)

set(CMAKE_INCLUDE_CURRENT_DIR On)

add_library(dvm SHARED
    Assembler.d
    Compiler.d
    FileSystem.d
    OperatingSystem.d
    Utilities.d
    VirtualMachine.d
)

add_executable(cm cm.d)
target_link_libraries(cm dvm)

add_executable(as as.d)
target_link_libraries(as dvm)

add_executable(os os.d)
target_link_libraries(os dvm)

add_executable(fs fs.d)
target_link_libraries(fs dvm)

add_subdirectory(test)
