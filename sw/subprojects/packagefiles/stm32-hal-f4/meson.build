project('stm32-hal-f4', version: '1.8.3')

family = 'F4'
hal_components = get_option('hal_components')

hal_src = []
hal_comp_prefix = 'stm32' + family.to_lower() + 'xx_hal'
hal_src += 'Src' / hal_comp_prefix + '.c'
foreach comp : hal_components
    hal_src += 'Src' / hal_comp_prefix + '_' + comp + '.c'
endforeach

hal_inc = [
    '.',
    'Inc',
]

hal_conf_prefix = 'stm32' + family.to_lower() + 'xx_hal_conf'
configure_file(
    copy: true,
    input: 'Inc' / hal_conf_prefix + '_template.h',
    output: hal_conf_prefix + '.h',
)

hal_dep = declare_dependency(
    sources: files(hal_src),
    include_directories: include_directories(hal_inc),
)
meson.override_dependency(meson.project_name(), hal_dep)
