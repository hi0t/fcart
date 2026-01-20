tests = files(
    'api_tb.sv',
    'fifo_tb.sv',
    'qspi_tb.sv',
    'sdram_tb.sv',
)

questa_path = get_option('questa_search_path')
if questa_path == ''
    questa_path = []
endif

if get_option('hw_use_docker')
    py = import('python').find_installation(required: true)
    docker_cmd = meson.project_source_root() / 'hw/docker/docker_cmd.py'
    vlog_exe = [py, docker_cmd, 'build', 'vlog']
    vsim_exe = py
    vsim_args = [docker_cmd, 'bench', 'vsim']
else
    vlog_exe = [find_program('vlog', 'vlog.exe', dirs: questa_path, required: true)]
    vsim_exe = find_program('vsim', 'vsim.exe', dirs: questa_path, required: true)
    vsim_args = []
endif

fs = import('fs')
build_dir = meson.project_build_root()
work = custom_target(
    'sim_work',
    build_always_stale: true,
    command: [
        vlog_exe,
        '+libext+.sv+.vp+.v',
        '-work', '@OUTPUT@',
        '-y', fs.relative_to(meson.project_source_root() / 'hw' / 'src', build_dir),
        '-y', fs.relative_to(meson.current_source_dir(), build_dir),
        '@INPUT@',
    ],
    input: tests,
    output: 'work',
)

foreach f : tests
    module = fs.stem(f)
    test(
        module,
        vsim_exe,
        args: [
            vsim_args,
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
