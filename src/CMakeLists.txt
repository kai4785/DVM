add_library(dvm SHARED
    Assembler.d
    Compiler.d
    FileSystem.d
    OperatingSystem.d
    Utilities.d
    VirtualMachine.d
)

foreach(exe cm as os fs)
    add_executable(${exe} ${exe}.d)
    target_link_libraries(${exe} dvm)
endforeach()
