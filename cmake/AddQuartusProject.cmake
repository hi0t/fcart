find_package(Quartus REQUIRED)

function(add_quartus_project target)
    set(project_dir "${CMAKE_BINARY_DIR}/quartus")
    set(qsf_file "${project_dir}/${target}.qsf")
    set(bitstream_file "${project_dir}/${target}.sof")
    set(depends ${qsf_file})
    set(cmake_dir "${CMAKE_SOURCE_DIR}/cmake")

    file(MAKE_DIRECTORY "${project_dir}")

    execute_process(
        COMMAND ${QUARTUS_SH} --tcl_eval project_new -family "${FAMILY}" -overwrite -part "${DEVICE}" ${target}
        WORKING_DIRECTORY ${project_dir}
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
        WORKING_DIRECTORY ${project_dir}
    )

    add_custom_command(
        OUTPUT __program__
        COMMAND ${QUARTUS_PGM} --mode=jtag -o \"P\;${bitstream_file}\"
        DEPENDS ${bitstream_file}
        WORKING_DIRECTORY ${project_dir}
    )

    add_custom_target(quartus-compile DEPENDS "${bitstream_file}")
    add_custom_target(quartus-program DEPENDS __program__)

    set_property(
        TARGET quartus-compile APPEND
        PROPERTY ADDITIONAL_CLEAN_FILES ${project_dir}
    )

    if (WIN32)
        set(DEVNUL NUL)
    else()
        set(DEVNUL /dev/null)
    endif()
    add_custom_command(TARGET quartus-compile POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        COMMAND ${QUARTUS_SH} -t ${cmake_dir}/QuartusReport.tcl ${target} > ${DEVNUL}
        COMMAND ${QUARTUS_STA} -t ${cmake_dir}/QuartusTimings.tcl ${target} > ${DEVNUL}
        WORKING_DIRECTORY ${project_dir}
    )
endfunction()
