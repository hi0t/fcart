bootloader_version = '0.1'

bootloader = files(
    'fpga_cfg.c',
    'main.c',
    'msc.c',
    'uf2.c',
    'virt_fat.c',
)

compile_args = [
    '-DBOOTLOADER_ADDRESS=@0@'.format(get_option('bootloader_address')),
    '-DAPP_ADDRESS=@0@'.format(get_option('app_address')),
]

if get_option('buildtype') == 'debug'
    compile_args += ['-Og', '-g', '-gdwarf-2']
elif get_option('buildtype') == 'release'
    compile_args += ['-O2']
endif

ver = bootloader_version.split('.')

bootloader_sw = declare_dependency(
    sources: bootloader,
    dependencies: drivers_dep,
    compile_args: compile_args,
    link_args: [
        '-Wl,--defsym=FLASH_ORIGIN=@0@'.format(get_option('bootloader_address')),
        '-Wl,--defsym=FLASH_SIZE=@0@K'.format(get_option('bootloader_size')),
        '-Wl,--defsym=APP_HEADER_MAGIC=@0@'.format(get_option('app_header_magic')),
        '-Wl,--defsym=PROJECT_VERSION_MAJOR=@0@'.format(ver[0]),
        '-Wl,--defsym=PROJECT_VERSION_MINOR=@0@'.format(ver[1]),
    ],
)
