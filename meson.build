project(
    'fcart',
    'c',
    version: '0.1',
    default_options: ['b_ndebug=if-release'],
    meson_version: '>=1.3',
)

subdir('hw')
subdir('sw')

objcopy = find_program('objcopy', native: false, required: true)

py = import('python').find_installation(required: true)

custom_target(
    'fcart.uf2',
    output: 'fcart.uf2',
    command: [
        py,
        meson.project_source_root() / 'make_uf2.py',
        '--app', fcart_elf,
        '--bitstream', bit,
        '--objcopy', objcopy,
        '--output', '@OUTPUT@',
    ],
    depends: [fcart_elf, bit],
    build_by_default: true,
)
