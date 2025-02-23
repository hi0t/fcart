include(FindPackageHandleStandardArgs)

set(QUESTA_HINTS
    ${QUESTA_ROOTDIR}
)

find_program(QUESTA_VLOG vlog vlog.exe
    HINTS ${QUESTA_HINTS}
    PATH_SUFFIXES win64
    DOC "Path to the Questa vlog executable"
)

find_program(QUESTA_VSIM vsim vsim.exe
    HINTS ${QUESTA_HINTS}
    PATH_SUFFIXES win64
    DOC "Path to the Questa vsim executable"
)

find_package_handle_standard_args(Questa REQUIRED_VARS QUESTA_VLOG QUESTA_VSIM)
