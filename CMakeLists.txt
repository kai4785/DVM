cmake_minimum_required(VERSION 3.10)

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake-d/cmake-d)

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

enable_testing()

set(asm_FILES
    memory.asm
    new_del.asm
    nums0.asm
    nums1.asm
    nums2.asm
    nums3.asm
    nums4.asm
    nums5.asm
    nums6.asm
    nums7.asm
    nums8.asm
    nums9.asm
    proj1.asm
    proj2.asm
    proj3.asm
    proj4.asm
)

foreach(asm_FILE ${asm_FILES})
    get_filename_component(asm_TARGET ${asm_FILE} NAME_WE)
    set(hex_FILE ${asm_TARGET}.hex)
    add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/${hex_FILE}
        COMMAND $<TARGET_FILE:as> ${CMAKE_CURRENT_SOURCE_DIR}/${asm_FILE} ${CMAKE_BINARY_DIR}/${hex_FILE}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${asm_FILE}
    )
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES ${CMAKE_BINARY_DIR}/${hex_FILE})
    add_custom_target(${asm_TARGET}_asm
        ALL
        DEPENDS ${CMAKE_BINARY_DIR}/${hex_FILE}
    )
endforeach()

set(test_FILES
    head_tail.test
    proj3-2.test
    proj3.test
    proj4.test
)

foreach(test_FILE ${test_FILES})
    get_filename_component(test_TARGET ${test_FILE} NAME_WE)
    add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/${test_FILE}
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/${test_FILE} ${CMAKE_BINARY_DIR}/${test_FILE}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${test_FILE}
    )
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES ${CMAKE_BINARY_DIR}/${test_FILE})
    add_custom_target(${test_TARGET}_test
        ALL
        DEPENDS ${CMAKE_BINARY_DIR}/${test_FILE}
    )
endforeach()

set(os_FILES
    compat.os
    compat_runall.os
    memory.os
    runall.os
    metrics.os
    io.os
    io_race.os
)
set(compat_os_setup_args
    --copy proj1.hex,proj2.hex,proj3.hex,proj4.hex,proj3.test,proj4.test,/
)
set(compat_runall_os_setup_args
    ${compat_os_setup_args}
)
set(runall_os_setup_args
    --copy nums0.hex,nums1.hex,nums2.hex,nums3.hex,nums4.hex,nums5.hex,nums6.hex,nums7.hex,nums8.hex,nums9.hex,/
)
set(memory_os_setup_args
    --copy memory.hex,/
)
set(metrics_os_setup_args
    ${runall_os_setup_args}
)
set(io_os_setup_args
    ${runall_os_setup_args}
)
set(io_race_os_setup_args
    ${runall_os_setup_args}
)

foreach(os_FILE ${os_FILES})
    get_filename_component(test ${os_FILE} NAME_WE)
    set(script ${CMAKE_CURRENT_SOURCE_DIR}/${os_FILE})
    set(disk ${CMAKE_CURRENT_BINARY_DIR}/${test}.DISK)
    add_test(NAME ${test}_os_setup
        COMMAND $<TARGET_FILE:fs> --disk ${disk} --mkfs --size 1048576 ${${test}_os_setup_args}
    )
    add_test(NAME ${test}_os
        COMMAND $<TARGET_FILE:os> --script ${script} --disk ${disk}
    )
    add_test(NAME ${test}_os_cleanup
        COMMAND ${CMAKE_COMMAND} -E remove -f ${disk}
    )
    set_tests_properties(${test}_os_setup   PROPERTIES FIXTURES_SETUP   ${test}_os_setup)
    set_tests_properties(${test}_os_cleanup PROPERTIES FIXTURES_CLEANUP ${test}_os_cleanup)

    set_tests_properties(${test}_os         PROPERTIES DEPENDS ${test}_os_setup)
    set_tests_properties(${test}_os_cleanup PROPERTIES DEPENDS ${test}_os)
endforeach()

set(sh_FILES
    disk.sh
    copy_files.sh
    fillup.sh
)

foreach(sh_FILE ${sh_FILES})
    get_filename_component(test ${sh_FILE} NAME_WE)
    add_test(NAME ${test}_sh
        COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/${sh_FILE}
    )
endforeach()

set(kxi_FILES
    DemoA.kxi
    DemoC.kxi
    DemoCMinus.kxi
    cntl_struct.kxi
    simple.kxi
    test.kxi
    #  test1.kxi fails to compile:
    #    [27][g.main] Error: Type mismatch in function signature: Got type "char" in the call when function declaration is expecting a "int".
    #    [28][g.main] Error: Type mismatch in function signature: Got type "char" in the call when function declaration is expecting a "int".
    #    Exception thrown! : Errors encountered: [2]
    #test1.kxi
    test2.kxi
    #  test3.kxi fails to compile:
    #    [81][g.main] Error: Argument list lengths don't match: Expected 0, got 2.
    #    Exception thrown! : Continuing from this point is pointless
    #test3.kxi
    test4.kxi
)

foreach(kxi_FILE ${kxi_FILES})
    get_filename_component(file_we ${kxi_FILE} NAME_WE)
    set(test ${file_we}_kxi)
    set(disk ${CMAKE_BINARY_DIR}/${test}.DISK)

    set(asm_FILE ${file_we}.asm)
    add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/${asm_FILE}
        COMMAND $<TARGET_FILE:cm> ${CMAKE_CURRENT_SOURCE_DIR}/${kxi_FILE} ${CMAKE_BINARY_DIR}/${asm_FILE}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${kxi_FILE}
    )
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES ${CMAKE_BINARY_DIR}/${asm_FILE})
    add_custom_target(${test}_asm
        ALL
        DEPENDS ${CMAKE_BINARY_DIR}/${asm_FILE}
    )

    set(hex_FILE ${file_we}.hex)
    add_custom_command(OUTPUT ${CMAKE_BINARY_DIR}/${hex_FILE}
        COMMAND $<TARGET_FILE:as> ${CMAKE_BINARY_DIR}/${asm_FILE} ${CMAKE_BINARY_DIR}/${hex_FILE}
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${asm_FILE}
    )
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES ${CMAKE_BINARY_DIR}/${hex_FILE})
    add_custom_target(${test}_hex
        ALL
        DEPENDS ${CMAKE_BINARY_DIR}/${hex_FILE}
    )

    add_test(NAME ${test}_setup
        COMMAND $<TARGET_FILE:fs> --disk ${disk} --mkfs --size 1048576 --copy ${hex_FILE},/
    )
    add_test(NAME ${test}
        COMMAND $<TARGET_FILE:os> --disk ${disk} --script /dev/null
    )
    add_test(NAME ${test}_cleanup
        COMMAND ${CMAKE_COMMAND} -E remove -f ${disk}
    )

    set_tests_properties(${test}_setup   PROPERTIES FIXTURES_SETUP   ${test}_setup)
    set_tests_properties(${test}_cleanup PROPERTIES FIXTURES_CLEANUP ${test}_cleanup)

    set_tests_properties(${test}         PROPERTIES DEPENDS ${test}_setup)
    set_tests_properties(${test}_cleanup PROPERTIES DEPENDS ${test})
endforeach()
