project('stm32-cmsis-f4', version: '2.6.11', meson_version: '>=1.1.0')

family = 'F4'
mcu_series = get_option('mcu_series')

cmsis_src = []
cmsis_src += 'Source' / 'Templates' / 'system_stm32' + family.to_lower() + 'xx.c'
cmsis_src += 'Source' / 'Templates' / 'gcc/startup_' + mcu_series.to_lower() + '.s'

cmsis_inc = [
    'Include',
]

cmsis_dep = declare_dependency(
    compile_args: ['-D' + mcu_series, '-DUSE_HAL_DRIVER'],
    sources: files(cmsis_src),
    include_directories: include_directories(cmsis_inc),
)
meson.override_dependency(meson.project_name(), cmsis_dep)
