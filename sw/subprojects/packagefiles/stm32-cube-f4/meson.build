project('stm32-cube-f4', version: '1.28.1')

family = 'F4'
mcu_series = get_option('mcu_series')
hal_components = get_option('hal_components')

# CMSIS
cmsis_dir = 'Drivers' / 'CMSIS'
device_dir = cmsis_dir / 'Device' / 'ST' / 'STM32' + family + 'xx'
cmsis_src = []
cmsis_src += device_dir / 'Source' / 'Templates' / 'system_stm32' + family.to_lower() + 'xx.c'
cmsis_src += device_dir / 'Source' / 'Templates' / 'gcc/startup_' + mcu_series.to_lower() + '.s'
cmsis_inc = [
    cmsis_dir / 'Include',
    device_dir / 'Include',
]
cmsis_dep = declare_dependency(
    compile_args: ['-D' + mcu_series],
    sources: files(cmsis_src),
    include_directories: include_directories(cmsis_inc),
)

# HAL
hal_dir = 'Drivers' / 'STM32' + family + 'xx_HAL_Driver'
hal_src = []
hal_comp_prefix = 'stm32' + family.to_lower() + 'xx_hal'
hal_src += hal_dir / 'Src' / hal_comp_prefix + '.c'
foreach comp : hal_components
    hal_src += hal_dir / 'Src' / hal_comp_prefix + '_' + comp + '.c'
endforeach
hal_inc = [
    '.',
    hal_dir / 'Inc',
]
hal_conf_prefix = 'stm32' + family.to_lower() + 'xx_hal_conf'
configure_file(
    copy: true,
    input: hal_dir / 'Inc' / hal_conf_prefix + '_template.h',
    output: hal_conf_prefix + '.h',
)
hal_dep = declare_dependency(
    sources: files(hal_src),
    include_directories: include_directories(hal_inc),
)
