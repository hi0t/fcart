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
        FPGA_ADDRESS = 0x09000000

        with open(bin_path, "rb") as f:
            fw_content = f.read()

        bit_path = os.path.join("hw", "builddir", "fcart.bit")
        bit_content = b""
        if os.path.exists(bit_path):
            with open(bit_path, "rb") as f:
                bit_content = f.read()
        else:
            print(f"Warning: Bitstream {bit_path} not found")

        fw_blocks = (len(fw_content) + 255) // 256
        bit_blocks = (len(bit_content) + 255) // 256
        total_blocks = fw_blocks + bit_blocks

        with open(uf2_path, "wb") as f:
            # Helper to write block
            def write_block(f, data, addr, blockno, num_blocks):
                hd = struct.pack(
                    "<IIIIIIII",
                    UF2_MAGIC_START0,
                    UF2_MAGIC_START1,
                    FLAGS,
                    addr,
                    256,
                    blockno,
                    num_blocks,
                    FAMILY_ID_STM32F4,
                )
                data_padded = data + b"\x00" * (476 - len(data))
                ft = struct.pack("<I", UF2_MAGIC_END)
                f.write(hd + data_padded + ft)

            # Write Firmware
            for i in range(fw_blocks):
                ptr = 256 * i
                chunk = fw_content[ptr : ptr + 256]
                write_block(f, chunk, APP_ADDRESS + ptr, i, total_blocks)

            # Write FPGA
            for i in range(bit_blocks):
                ptr = 256 * i
                chunk = bit_content[ptr : ptr + 256]
                write_block(f, chunk, FPGA_ADDRESS + ptr, fw_blocks + i, total_blocks)

        print(
            f"Successfully created {uf2_path} with {fw_blocks} FW blocks and {bit_blocks} FPGA blocks"
        )

    except Exception as e:
        print(f"Failed to create UF2: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
