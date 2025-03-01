src = files(
    'led.c',
    'soc.c',
)

cdata = configuration_data()
cdata.set('HEAP_SIZE', get_option('heap_size'))
cdata.set('STACK_SIZE', get_option('stack_size'))
cdata.set('RAM_ORIGIN', '0x20000000')
cdata.set('RAM_SIZE', get_option('ram_size'))
cdata.set('FLASH_ORIGIN', '0x8000000')
cdata.set('FLASH_SIZE', get_option('flash_size'))
# if mcu uses ccram need to add this section to .ld

configure_file(
    input: 'flash.ld.in',
    output: 'flash.ld',
    configuration: cdata,
)

hse_freq = get_option('hse_freq')
pll_divm = get_option('pll_divm')

drivers_dep = declare_dependency(
    compile_args: [
        f'-DHSE_VALUE=@hse_freq@',
        f'-DRCC_PLL_DIVM=@pll_divm@',
    ],
    dependencies: [
        dependency('stm32-cmsis'),
        dependency('stm32-cmsis-f4'),
        dependency('stm32-hal-f4'),
    ],
    include_directories: include_directories('.'),
    link_args: ['-T', meson.current_build_dir() / 'flash.ld'],
    sources: src,
)
