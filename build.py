#!/usr/bin/env python3

import os
import sys
import subprocess

# Configuration
BUILD_DIR = os.path.join("sw", "builddir")
TARGET = "fcart"
BUILD_TYPE = "release"


def run_command(cmd, cwd=None):
    print(f"Running: {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=cwd)
    if result.returncode != 0:
        print(f"Error executing command: {cmd}")
        sys.exit(1)


def main():
    # 1. Setup
    if not os.path.exists(BUILD_DIR):
        print(f"Creating build directory '{BUILD_DIR}'...")
        run_command(
            f"meson setup {BUILD_DIR} sw --cross-file sw/build.ini --buildtype={BUILD_TYPE}"
        )

    # 2. Compile
    print("Building project...")
    run_command(f"meson compile -C {BUILD_DIR} {TARGET}.elf bootloader.elf")

    # 3. Convert Bootloader
    bl_elf_path = os.path.join(BUILD_DIR, "bootloader.elf")
    bl_bin_path = os.path.join(BUILD_DIR, "bootloader.bin")

    print("Converting Bootloader ELF to BIN...")
    run_command(f"arm-none-eabi-objcopy -O binary {bl_elf_path} -S {bl_bin_path}")

    # 4. Convert to UF2
    elf_path = os.path.join(BUILD_DIR, f"{TARGET}.elf")
    bin_path = os.path.join(BUILD_DIR, f"{TARGET}.bin")
    uf2_path = os.path.join(BUILD_DIR, f"{TARGET}.uf2")

    # ELF -> BIN
    if not os.path.exists(bin_path):
        print("Converting ELF to BIN...")
        run_command(f"arm-none-eabi-objcopy -O binary {elf_path} -S {bin_path}")

    # BIN -> UF2
    print(f"Generating {uf2_path}...")
    try:
        import struct

        UF2_MAGIC_START0 = 0x0A324655
        UF2_MAGIC_START1 = 0x9E5D5157
        UF2_MAGIC_END = 0x0AB16F30
        FAMILY_ID_STM32F4 = 0x57755A57
        FLAGS = 0x00002000  # FamilyID present

        # Target address (see sw/bootloader/meson.build)
        APP_ADDRESS = 0x08010000

        with open(bin_path, "rb") as f:
            content = f.read()

        num_blocks = (len(content) + 255) // 256

        with open(uf2_path, "wb") as f:
            for blockno in range(num_blocks):
                ptr = 256 * blockno
                chunk = content[ptr : ptr + 256]

                # Header
                hd = struct.pack(
                    "<IIIIIIII",
                    UF2_MAGIC_START0,
                    UF2_MAGIC_START1,
                    FLAGS,
                    APP_ADDRESS + ptr,
                    256,  # payload size
                    blockno,
                    num_blocks,
                    FAMILY_ID_STM32F4,
                )

                # Data (padded to 476 bytes)
                data_padded = chunk + b"\x00" * (476 - len(chunk))

                # Footer
                ft = struct.pack("<I", UF2_MAGIC_END)

                f.write(hd + data_padded + ft)

        print(f"Successfully created {uf2_path}")

    except Exception as e:
        print(f"Failed to create UF2: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
