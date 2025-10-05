ca65 = find_program('ca65', 'ca65.exe', required: true)
ld65 = find_program('ld65', 'ld65.exe', required: true)

launcher_main = custom_target(
    'main.o',
    input: 'main.s',
    output: 'main.o',
    command: [ca65, '-o', '@OUTPUT@', '-t', 'nes', '@INPUT@'],
)

launcher_debug = custom_target(
    'debug.o',
    input: 'debug.s',
    output: 'debug.o',
    command: [ca65, '-o', '@OUTPUT@', '-t', 'nes', '@INPUT@'],
)

launcher_cfg = files('nes.cfg')
launcher_nes = custom_target(
    'launcher.nes',
    input: launcher_main,
    output: 'launcher.nes',
    command: [ld65, '-o', '@OUTPUT@', '-C', launcher_cfg, '@INPUT@'],
)

py = import('python').find_installation(required: true)
launcher_mem = custom_target(
    'launcher.mem',
    input: launcher_nes,
    output: 'launcher.mem',
    command: [py.full_path(), files('mem.py'), '@INPUT@', '@OUTPUT@'],
)

launcher_debug_cfg = files('nes_debug.cfg')
custom_target(
    'launcher_debug.nes',
    input: [
        launcher_main,
        launcher_debug,
    ],
    output: 'launcher_debug.nes',
    command: [ld65, '-o', '@OUTPUT@', '-C', launcher_debug_cfg, '@INPUT@'],
)
