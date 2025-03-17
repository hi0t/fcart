tests = files('qspi_tb.sv')

vlog = find_program('vlog', required: true)
vsim = find_program('vsim', required: true)

fs = import('fs')

src_dir = fs.parent(meson.current_source_dir()) / 'src'
work = custom_target(
    'sim_work',
    build_always_stale: true,
    command: [
        vlog,
        '-work', '@OUTPUT@',
        '+libext+.sv+.vp+.v',
        '-y', src_dir,
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
    )
endforeach
