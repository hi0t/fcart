src = files(
    'dirlist.c',
    'err.c',
    'fpga_api.c',
    'fpga_cfg.c',
    'gfx.c',
    'joypad.c',
    'main.c',
    'rom.c',
    'ui.c',
)

fcart_sw = declare_dependency(
    sources: src,
    dependencies: drivers_dep,
    link_args: [
        '-Wl,--defsym=FLASH_ORIGIN=0x8008000',
        '-Wl,--defsym=FLASH_SIZE=@0@K'.format(get_option('flash_size') - 32),
    ],
)
