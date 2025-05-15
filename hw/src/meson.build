src = files(
    'ip' / 'pll.v',
    'bidir_bus.sv',
    'sdram_bus.sv',
    'api.sv',
    'chr_rom.sv',
    'fcart.sv',
    'fifo.sv',
    'prg_rom.sv',
    'qspi.sv',
    'sdram.sv',
)

lpf = files('fcart.lpf')
sdc = files('fcart.sdc')

rtl_sorces = [src, lpf, sdc]

src_dir = meson.project_source_root()
fs = import('fs')
src_list = []
foreach f : src
    src_list += 'prj_src add "@0@"'.format(src_dir / fs.parent(f) / fs.name(f))
endforeach

tcl = configure_file(
    input: 'diamond.tcl.in',
    output: 'diamond.tcl',
    configuration: {
        'PROJECT_NAME': diamond_prj,
        'DEVICE': get_option('device'),
        'LPF_PATH': src_dir / fs.parent(lpf) / fs.name(lpf),
        'SDC_PATH': src_dir / fs.parent(sdc) / fs.name(sdc),
        'SRL_LIST': '\n'.join(src_list),
        'TOP_MODULE': diamond_prj,
    },
)
