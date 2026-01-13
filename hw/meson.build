diamond_prj = 'fcart'

subdir('bench')
subdir('src')
subdir('launcher')

py = import('python').find_installation(required: true)

diamond_path = get_option('diamond_search_path')
if diamond_path == ''
    diamond_path = []
endif

if get_option('hw_use_docker')
    diamondc_cmd = [
        py,
        meson.project_source_root() / 'hw/docker/docker_cmd.py',
        'build',
        'diamondc',
    ]
else
    diamondc = find_program('pnmainc.exe', 'diamondc', dirs: diamond_path, required: true)
    diamondc_cmd = [diamondc]
endif

bit = custom_target(
    f'@diamond_prj@.bit',
    input: tcl,
    output: f'@diamond_prj@.bit',
    command: diamondc_cmd + ['@INPUT@'],
    depend_files: rtl_sorces,
    depends: launcher_mem,
    console: true,
)

run_target(
    'summary',
    command: [
        py.full_path(),
        files('summary.py'),
        'hw/impl/automake.log',
        'hw/impl/fcart_impl.twr',
    ],
    depends: bit,
)

openfpgaloader = find_program('openfpgaloader', required: false)
if openfpgaloader.found()
    run_target(
        'program',
        command: [openfpgaloader, '-c', get_option('fpga_cable'), bit],
    )
endif
