src = files(
    'ip' / 'pll.v',
    'qspi_bus.sv',
    'sdram_bus.sv',
    'api.sv',
    'fcart.sv',
    'qspi.sv',
    'sdram.sv',
)

lpf = files('fcart.lpf')

proj_dir = meson.project_source_root()
fs = import('fs')
src_list = []
foreach f : src
    src_list += 'prj_src add "@0@"'.format(proj_dir / fs.parent(f) / fs.name(f))
endforeach

tcl = configure_file(
    input: 'diamond.tcl.in',
    output: 'diamond.tcl',
    configuration: {
        'PROJECT_NAME': diamond_prj,
        'DEVICE': get_option('device'),
        'PROJECT_PATH': meson.project_build_root(),
        'SRL_LIST': '\n'.join(src_list),
        'LPF_PATH': proj_dir / fs.parent(lpf) / fs.name(lpf),
        'TOP_MODULE': diamond_prj,
    },

)
