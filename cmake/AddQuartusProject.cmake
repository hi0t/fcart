find_package(Quartus REQUIRED)

function(add_quartus_project target)
    set(QUARTUS_PROJECT_DIR "${CMAKE_BINARY_DIR}/quartus/${target}")
    set(QUARTUS_PROJECT_DIR ${QUARTUS_PROJECT_DIR} PARENT_SCOPE)
    set(qsf_file "${QUARTUS_PROJECT_DIR}/${target}.qsf")
    set(bitstream_file "${QUARTUS_PROJECT_DIR}/${target}.sof")
    set(depends ${qsf_file})
    set(cmake_dir "${CMAKE_SOURCE_DIR}/cmake")

    file(MAKE_DIRECTORY "${QUARTUS_PROJECT_DIR}")

    execute_process(
        COMMAND ${QUARTUS_SH} --tcl_eval project_new -family "${FAMILY}" -overwrite -part "${DEVICE}" ${target}
        WORKING_DIRECTORY ${QUARTUS_PROJECT_DIR}
    )

    set_property(
        DIRECTORY
        APPEND
        PROPERTY CMAKE_CONFIGURE_DEPENDS
        ${qsf_file}
    )

    file(APPEND ${qsf_file} "\nset_global_assignment -name NUM_PARALLEL_PROCESSORS ALL\n\n")
        foreach (src ${SRC})
        if (src MATCHES "\\.sv$")
            set(type SYSTEMVERILOG_FILE)
        elseif (src MATCHES "\\.vhd$")
            set(type VHDL_FILE)
        elseif (src MATCHES "\\.v$")
            set(type VERILOG_FILE)
        else()
            continue()
        endif()
        file(APPEND ${qsf_file} "set_global_assignment -name ${type} ${src}\n")
        list(APPEND depends "${src}")
    endforeach()
    foreach (tcl ${TCL})
        file(APPEND ${qsf_file} "set_global_assignment -name SOURCE_TCL_SCRIPT_FILE ${tcl}\n")
        list(APPEND depends "${tcl}")
    endforeach()
    foreach (sdc ${SDC})
        file(APPEND ${qsf_file} "set_global_assignment -name SDC_FILE ${sdc}\n")
        list(APPEND depends "${sdc}")
    endforeach()

    add_custom_command(
        OUTPUT ${bitstream_file}
        COMMAND ${QUARTUS_SH} --flow compile ${target}
        DEPENDS ${depends}
        WORKING_DIRECTORY ${QUARTUS_PROJECT_DIR}
    )

    add_custom_command(
        OUTPUT __program__
        COMMAND ${QUARTUS_PGM} --mode=jtag -o \"P\;${bitstream_file}\"
        DEPENDS ${bitstream_file}
        WORKING_DIRECTORY ${QUARTUS_PROJECT_DIR}
    )

    add_custom_target(${target}-compile DEPENDS "${bitstream_file}")
    add_custom_target(${target}-program DEPENDS __program__)

    set_property(
        TARGET ${target}-compile APPEND
        PROPERTY ADDITIONAL_CLEAN_FILES ${QUARTUS_PROJECT_DIR}
    )

    if (WIN32)
        set(DEVNUL NUL)
    else()
        set(DEVNUL /dev/null)
    endif()
    add_custom_command(TARGET ${target}-compile POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        COMMAND ${QUARTUS_SH} -t ${cmake_dir}/QuartusReport.tcl ${target} > ${DEVNUL}
        COMMAND ${QUARTUS_STA} -t ${cmake_dir}/QuartusTimings.tcl ${target} > ${DEVNUL}
        WORKING_DIRECTORY ${QUARTUS_PROJECT_DIR}
    )
endfunction()
