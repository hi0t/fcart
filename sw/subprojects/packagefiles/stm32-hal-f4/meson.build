project('stm32-hal-f4', version: '1.8.3')

family = 'F4'

hal_src = []
hal_comp_prefix = 'stm32' + family.to_lower() + 'xx_'
hal_src += 'Src' / hal_comp_prefix + 'hal.c'
foreach comp : get_option('hal_modules')
    hal_src += 'Src' / hal_comp_prefix + comp + '.c'
endforeach

hal_inc = [
    'Inc',
]

hal_conf_prefix = 'stm32' + family.to_lower() + 'xx_hal_conf'
py = import('python').find_installation()
run_command(
    py,
    'gen_hal_conf.py',
    '--input=' + 'Inc' / hal_conf_prefix + '_template.h',
    '--output=' + 'Inc' / hal_conf_prefix + '.h',
    '--hal_callbacks=' + ','.join(get_option('hal_callbacks')),
    check: true,
)

hal_dep = declare_dependency(
    sources: files(hal_src),
    include_directories: include_directories(hal_inc),
)
meson.override_dependency(meson.project_name(), hal_dep)
