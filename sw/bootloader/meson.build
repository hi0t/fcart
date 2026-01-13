bootloader = files('main.c', 'msc.c', 'virt_fat.c', 'uf2.c')

bootloader_sw = declare_dependency(
    sources: bootloader,
    dependencies: drivers_dep,
    compile_args: ['-DAPP_ADDRESS=0x08010000'],
    link_args: [
        '-Wl,--defsym=FLASH_ORIGIN=0x8000000',
        '-Wl,--defsym=FLASH_SIZE=64K',
    ],
)
