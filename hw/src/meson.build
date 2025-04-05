src = files(
    'ip' / 'pll.v',
    'api.sv',
    'chr_rom.sv',
    'fcart.sdc',
    'fcart.sv',
    'prg_rom.sv',
    'sdram_bus.sv',
    'sdram.sv',
    'spi.sv',
    'spi_bus.sv',
)

fs = import('fs')
src_list = []
foreach f : src
    file_name = fs.name(f)
    if file_name.endswith('.sv')
        file_type = 'SYSTEMVERILOG_FILE'
    elif file_name.endswith('.v')
        file_type = 'VERILOG_FILE'
    elif file_name.endswith('.sdc')
        file_type = 'SDC_FILE'
    else
        error('Unknown file type for @0@'.format(f))
    endif

    src_list += 'set_global_assignment -name @0@ "@1@"'.format(file_type, fs.relative_to(f, meson.project_build_root()))
endforeach

tcl = configure_file(
    input: 'quartus.tcl.in',
    output: 'quartus.tcl',
    configuration: {
        'PROJECT_NAME': quartus_proj,
        'FAMILY': get_option('family'),
        'DEVICE': get_option('device'),
        'SRL_LIST': '\n'.join(src_list),
    },
)
