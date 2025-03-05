src = files('fcart.sv')

lpf = files('fcart.lpf')

curr_dir = meson.current_source_dir()
fs = import('fs')
src_list = []
foreach f : src
    src_list += 'prj_src add "@0@"'.format(curr_dir / fs.name(f))
endforeach

tcl = configure_file(
    input: 'diamond.tcl.in',
    output: 'diamond.tcl',
    configuration: {
        'PROJECT_NAME': diamond_prj,
        'DEVICE': get_option('device'),
        'PROJECT_PATH': meson.project_build_root(),
        'SRL_LIST': '\n'.join(src_list),
        'LPF_PATH': curr_dir / fs.name(lpf),
        'TOP_MODULE': diamond_prj,
    },

)
