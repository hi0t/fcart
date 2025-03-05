project(
    'fcart-fw',
    version: '0.1',
)

diamond_prj = 'fcart'

subdir('src')

build_script = get_option('diamond_build_script')

if build_script != ''
    diamond_tool = find_program(
        build_script,
        required: true,
    )
else
    diamond_tool = find_program(
        'pnmainc.exe',
        'diamondc',
        dirs: get_option('diamond_path'),
        required: true,
    )
endif

bit = custom_target(
    f'@diamond_prj@.bit',
    input: tcl,
    output: f'@diamond_prj@.bit',
    command: [diamond_tool, '@INPUT@'],
    depend_files: [src, lpf],
    console: true,
)

py = import('python').find_installation()
curr_dir = meson.current_source_dir()
run_target(
    'summary',
    command: [
        py,
        curr_dir / 'summary.py',
        'impl/automake.log',
        f'impl/@diamond_prj@_impl.twr',
    ],
    depends: bit,
)
