src = files(
    'dirlist.c',
    'err.c',
    'fpga_api.c',
    'gfx.c',
    'joypad.c',
    'main.c',
    'msc.c',
    'rom.c',
    'ui.c',
)

ver = meson.project_version().split('.')

fcart_sw = declare_dependency(
    sources: src,
    dependencies: drivers_dep,
    compile_args: ['-DENABLE_SD_FS', '-DCFG_TUD_CDC=1'],
    link_args: [
        '-Wl,--defsym=FLASH_ORIGIN=@0@'.format(get_option('app_address')),
        '-Wl,--defsym=FLASH_SIZE=@0@K'.format(get_option('flash_size') - get_option('bootloader_size')),
        '-Wl,--defsym=PROJECT_VERSION_MAJOR=@0@'.format(ver[0]),
        '-Wl,--defsym=PROJECT_VERSION_MINOR=@0@'.format(ver[1]),
        '-Wl,--defsym=APP_HEADER_MAGIC=@0@'.format(get_option('app_header_magic')),
    ],
)
