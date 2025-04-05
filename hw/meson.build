project(
    'fcart-hw',
    version: '0.1',
    meson_version: '>=1.3',
)

quartus_proj = 'fcart'

subdir('bench')
subdir('src')

quartus_sh = find_program(
    'quartus_sh',
    'quartus_sh.exe',
    dirs: get_option('quartus_search_path'),
    required: true,
)

qsf = custom_target(
    'quartus project',
    input: tcl,
    output: f'@quartus_proj@.qsf',
    command: [quartus_sh, '-t', '@INPUT@'],
    depend_files: [src],
)

pof = custom_target(
    f'@quartus_proj@.pof',
    input: qsf,
    output: f'@quartus_proj@.pof',
    command: [quartus_sh, '--flow', 'compile', f'@quartus_proj@'],
    console: true,
)
