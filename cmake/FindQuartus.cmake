include(FindPackageHandleStandardArgs)

set(QUARTUS_HINTS
    ${QUARTUS_ROOTDIR}
)

find_program(QUARTUS_SH quartus_sh quartus_sh.exe
    HINTS ${QUARTUS_HINTS}
    PATH_SUFFIXES bin bin64
    DOC "Path to the Quartus sh executable"
)

find_program(QUARTUS_PGM quartus_pgm quartus_pgm.exe
    HINTS ${QUARTUS_HINTS}
    PATH_SUFFIXES bin bin64
    DOC "Path to the Quartus pgm executable"
)

find_program(QUARTUS_STA quartus_sta quartus_sta.exe
    HINTS ${QUARTUS_HINTS}
    PATH_SUFFIXES bin bin64
    DOC "Path to the Quartus sta executable"
)

find_package_handle_standard_args(Quartus REQUIRED_VARS QUARTUS_SH QUARTUS_PGM QUARTUS_STA)
