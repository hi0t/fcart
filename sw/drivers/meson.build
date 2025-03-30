drivers_src = files(
    'assert.c',
    'hal_msp.c',
    'interrupts.c',
    'log.c',
    'qspi.c',
    'soc.c',
    'spi.c',
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

compile_args = []
compile_args += '-DUSE_FULL_ASSERT'
compile_args += '-DDEFAULT_LOG_LEVEL=@0@'.format(get_option('default_log_level'))
compile_args += '-DHSE_VALUE=@0@'.format(get_option('hse_freq'))
compile_args += '-DRCC_PLL_DIVM=@0@'.format(get_option('pll_divm'))
foreach ctrl : get_option('pinctrl')
    p = ctrl.split('=')
    compile_args += '-DGPIO_@0@_PORT=GPIO@1@'.format(p[0].to_upper(), p[1][1].to_upper())
    compile_args += '-DGPIO_@0@_PIN=GPIO_PIN_@1@'.format(p[0].to_upper(), p[1].substring(2).to_upper())
    compile_args += '-DGPIO@0@_CLK_ENABLE'.format(p[1][1].to_upper())
endforeach

if get_option('buildtype') == 'debug'
    compile_args += ['-g', '-gdwarf-2']
endif

link_args = []
link_args += ['-T' + meson.current_build_dir() / 'flash.ld']
link_args += '-lc'

if get_option('enable_semihosting')
    compile_args += '-DENABLE_SEMIHOSTING'
    link_args += ['-specs=rdimon.specs', '-lrdimon']
else
    drivers_src += files('syscalls.c')
endif

subdir('fatfs')

drivers_dep = declare_dependency(
    compile_args: compile_args,
    dependencies: [
        dependency('stm32-cmsis'),
        dependency('stm32-cmsis-f4'),
        dependency('stm32-hal-f4'),
        fatfs_dep,
    ],
    include_directories: include_directories('.'),
    link_args: link_args,
    sources: drivers_src,
)
