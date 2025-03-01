project('stm32-cmsis', version: '5.9.0')

cmsis_inc = [
    'Include',
]

cmsis_dep = declare_dependency(
    include_directories: include_directories(cmsis_inc),
)
meson.override_dependency(meson.project_name(), cmsis_dep)
