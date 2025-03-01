src = files(
    'led.c',
    'soc.c',
)

cdata = configuration_data()
cdata.set('HEAP_SIZE', get_option('stm32_heap_size'))
cdata.set('STACK_SIZE', get_option('stm32_stack_size'))
cdata.set('RAM_ORIGIN', get_option('stm32_ram_origin'))
cdata.set('RAM_SIZE', get_option('stm32_ram_size'))
cdata.set('FLASH_ORIGIN', get_option('stm32_flash_origin'))
cdata.set('FLASH_SIZE', get_option('stm32_flash_size'))
# if mcu uses ccram need to add this section to .ld

configure_file(
    input: 'flash.ld.in',
    output: 'flash.ld',
    configuration: cdata,
)

stm32_cube = subproject('stm32-cube-f4')
cmsis_dep = stm32_cube.get_variable('cmsis_dep')
hal_dep = stm32_cube.get_variable('hal_dep')

drivers_dep = declare_dependency(
    compile_args: ['-DHSE_VALUE=8000000U'],
    dependencies: [cmsis_dep, hal_dep],
    include_directories: include_directories('.'),
    link_args: ['-T', meson.current_build_dir() / 'flash.ld'],
    sources: src,
)
