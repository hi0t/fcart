src = files(
    'ip' / 'pll.v',
    'map_bus.sv',
    'sdram_bus.sv',
    'api.sv',
    'state_recorder.sv',
    'chr_ram.sv',
    'fcart.sv',
    'fifo.sv',
    'joy_snoop.sv',
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

build_dir = meson.project_build_root() / 'hw'
fs = import('fs')
src_list = []
foreach f : src
    src_list += 'prj_src add "@0@"'.format(fs.relative_to(f, build_dir))
endforeach

# Generate parallel config file for Diamond
system = (host_machine.system() == 'windows' and not get_option('hw_use_docker')) ? 'PC' : 'Linux'
hostname_expr = get_option('hw_use_docker') ? '\'diamond\'' : 'socket.gethostname()'
parallel_conf = configure_file(
    output: 'parallel.conf',
    capture: true,
    command: [
        py,
        '-c',
        f'import multiprocessing; import socket; print(f"[{@hostname_expr@}]"); print("SYSTEM=@system@"); print(f"CORENUM=" + str(multiprocessing.cpu_count()))',
    ],
)

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
        'VERSION': meson.project_version(),
        'PARALLEL_CONF': fs.relative_to(parallel_conf, build_dir),
    },
)
