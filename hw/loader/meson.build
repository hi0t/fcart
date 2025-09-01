ca65 = find_program('ca65', 'ca65.exe', required: true)
ld65 = find_program('ld65', 'ld65.exe', required: true)

loader_main = custom_target(
    'main.o',
    input: 'main.s',
    output: 'main.o',
    command: [ca65, '-o', '@OUTPUT@', '-t', 'nes', '@INPUT@'],
)

loader_debug = custom_target(
    'debug.o',
    input: 'debug.s',
    output: 'debug.o',
    command: [ca65, '-o', '@OUTPUT@', '-t', 'nes', '@INPUT@'],
)

loader_cfg = files('nes.cfg')
loader_nes = custom_target(
    'loader.nes',
    input: loader_main,
    output: 'loader.nes',
    command: [ld65, '-o', '@OUTPUT@', '-C', loader_cfg, '@INPUT@'],
)

py = import('python').find_installation(required: true)
loader_mem = custom_target(
    'loader.mem',
    input: loader_nes,
    output: 'loader.mem',
    command: [py.full_path(), files('mem.py'), '@INPUT@', '@OUTPUT@'],
)

loader_debug_cfg = files('nes_debug.cfg')
custom_target(
    'loader_debug.nes',
    input: [
        loader_main,
        loader_debug,
    ],
    output: 'loader_debug.nes',
    command: [ld65, '-o', '@OUTPUT@', '-C', loader_debug_cfg, '@INPUT@'],
)
