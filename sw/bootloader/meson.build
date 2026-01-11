bootloader = files(
    'main.c',
)

bootloader_sw = declare_dependency(
    sources: bootloader,
    dependencies: drivers_dep,
    compile_args: ['-DAPP_ADDRESS=0x08008000'],
    link_args: [
        '-Wl,--defsym=FLASH_ORIGIN=0x8000000',
        '-Wl,--defsym=FLASH_SIZE=32K',
    ],
)
