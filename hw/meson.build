project(
    'fcart-hw',
    version: '0.1',
    meson_version: '>=1.3',
)

diamond_prj = 'fcart'

subdir('bench')
subdir('src')

diamond_path = get_option('diamond_search_path')
if diamond_path == ''
    diamond_path = []
endif
diamondc = find_program(
    'pnmainc.exe',
    'diamondc',
    dirs: diamond_path,
    required: true,
)

bit = custom_target(
    f'@diamond_prj@.bit',
    input: tcl,
    output: f'@diamond_prj@.bit',
    command: [diamondc, '@INPUT@'],
    depend_files: rtl_sorces,
    console: true,
)
