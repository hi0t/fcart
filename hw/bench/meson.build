tests = files('sdram_tb.sv', 'spi_tb.sv')

vlog = find_program('vlog', 'vlog.exe', dirs: get_option('questa_search_path'), required: true)
vsim = find_program('vsim', 'vsim.exe', dirs: get_option('questa_search_path'), required: true)

fs = import('fs')

work = custom_target(
    'sim_work',
    build_always_stale: true,
    command: [
        vlog,
        '+libext+.sv+.vp+.v',
        '-work', '@OUTPUT@',
        '-y', meson.project_source_root() / 'src',
        '-y', meson.current_source_dir(),
        '@INPUT@',
    ],
    input: tests,
    output: 'work',
)

foreach f : tests
    module = fs.stem(f)
    test(
        module,
        vsim,
        args: [
            '-c',
            '-voptargs=-debug',
            '-onfinish', 'stop',
            '-do', 'run -all; quit -code [coverage attribute -name TESTSTATUS -concise]',
            module,
        ],
        depends: work,
        workdir: meson.current_build_dir(),
        verbose: true,
    )
endforeach
