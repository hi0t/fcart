assert(
    meson.is_cross_build(),
    'fcart-sw must be cross-compiled. Add --cross-file=build.ini to meson command line',
)

cc = meson.get_compiler('c')
assert(cc.get_id() == 'gcc', 'fcart-sw must be compiled with GCC')

subdir('drivers')
subdir('bootloader')
subdir('src')

size = find_program('size')

fcart_elf = executable(
    'fcart.elf',
    dependencies: fcart_sw,
)

run_target(
    'fcart_size',
    command: [size, fcart_elf.full_path(), '-B'],
    depends: fcart_elf,
)

bootloader_elf = executable(
    'bootloader.elf',
    dependencies: bootloader_sw,
)

objcopy = find_program('objcopy', native: false, required: true)
custom_target(
    'bootloader.bin',
    output: 'bootloader.bin',
    command: [objcopy, '-O', 'binary', '@INPUT@', '-S', '@OUTPUT@'],
    input: bootloader_elf,
    build_by_default: true,
)

run_target(
    'bootloader_size',
    command: [size, bootloader_elf.full_path(), '-B'],
    depends: bootloader_elf,
)
