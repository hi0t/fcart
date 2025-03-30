project(
    'fcart-hw',
    version: '0.1',
    meson_version: '>=1.1',
)

diamond_prj = 'fcart'

subdir('bench')
subdir('src')

diamondc = find_program(
    'pnmainc.exe',
    'diamondc',
    required: true,
)

bit = custom_target(
    f'@diamond_prj@.bit',
    input: tcl,
    output: f'@diamond_prj@.bit',
    command: [diamondc, '@INPUT@'],
    depend_files: [src, lpf, sdc],
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
