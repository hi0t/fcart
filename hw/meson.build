project(
    'fcart-hw',
    version: '0.1',
    meson_version: '>=1.3',
)

diamond_prj = 'fcart'

subdir('bench')
subdir('src')
subdir('loader')

diamond_path = get_option('diamond_search_path')
if diamond_path == ''
    diamond_path = []
endif

diamondc = get_option('diamondc_custom_cmd')
if diamondc.length() == 0
    diamondc = [
        find_program('pnmainc.exe', 'diamondc', dirs: diamond_path, required: true),
    ]
endif

bit = custom_target(
    f'@diamond_prj@.bit',
    input: tcl,
    output: f'@diamond_prj@.bit',
    command: [diamondc, '@INPUT@'],
    depend_files: rtl_sorces,
    depends: loader_mem,
    console: true,
)

openfpgaloader = find_program('openfpgaloader', required: false)
if openfpgaloader.found()
    run_target(
        'program',
        command: [openfpgaloader, '-c', get_option('fpga_cable'), bit],
    )
endif
