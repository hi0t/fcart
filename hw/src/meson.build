src = files(
    'ip' / 'pll.v',
    'map_bus.sv',
    'sdram_bus.sv',
    'api.sv',
    'chr_ram.sv',
    'fcart.sv',
    'map_mux.sv',
    'prg_ram.sv',
    'qspi.sv',
    'sdram.sv',
    'snd_dac.sv',
)

subdir('mappers')

lpf = files('fcart.lpf')
sdc = files('fcart.sdc')

rtl_sorces = [src, lpf, sdc]

build_dir = meson.project_build_root()
fs = import('fs')
src_list = []
foreach f : src
    src_list += 'prj_src add "@0@"'.format(fs.relative_to(f, build_dir))
endforeach

tcl = configure_file(
    input: 'diamond.tcl.in',
    output: 'diamond.tcl',
    configuration: {
        'PROJECT_NAME': diamond_prj,
        'DEVICE': get_option('device'),
        'LPF_PATH': fs.relative_to(lpf, build_dir),
        'SDC_PATH': fs.relative_to(sdc, build_dir),
        'SRL_LIST': '\n'.join(src_list),
        'TOP_MODULE': diamond_prj,
        'STRATEGY': get_option('debug') ? 'Debug' : 'Release',
    },
)
