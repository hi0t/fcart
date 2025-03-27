project(
    'fcart-sw',
    'c',
    version: '0.1',
    default_options: ['b_ndebug=if-release'],
    meson_version: '>=1.1',
)

fs = import('fs')

assert(
    meson.is_cross_build(),
    'fcart-sw must be cross-compiled. Add --cross-file=build.ini to meson command line',
)

cc = meson.get_compiler('c')
assert(cc.get_id() == 'gcc', 'fcart-sw must be compiled with GCC')

subdir('drivers')
subdir('src')

size = find_program('size')
objcopy = find_program('objcopy')

fcart_elf = executable('fcart_sw.elf', dependencies: fcart_sw)
custom_target(
    output: fs.replace_suffix(fcart_elf.name(), '.bin'),
    input: fcart_elf,
    command: [objcopy, ['-O', 'binary', '-S', '@INPUT@', '@OUTPUT@']],
    depends: fcart_elf,
    build_by_default: true,
)
run_target(
    'size',
    command: [size, fcart_elf.full_path(), '-B'],
    depends: fcart_elf,
)
