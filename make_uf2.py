#!/usr/bin/env python3

import os
import sys
import subprocess
import argparse
import struct


def run_command(cmd, cwd=None):
    result = subprocess.run(cmd, shell=True, cwd=cwd)
    if result.returncode != 0:
        print(f"Error executing command: {cmd}")
        sys.exit(1)


def convert_elf_to_bin(objcopy, elf_path, bin_path):
    run_command(f"{objcopy} -O binary {elf_path} -S {bin_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate UF2 firmware")
    parser.add_argument("--app", required=True, help="Path to application ELF")
    parser.add_argument("--objcopy", required=True, help="Path to objcopy tool")
    parser.add_argument("--bitstream", help="Path to FPGA bitstream")
    parser.add_argument("-o", "--output", required=True, help="Output UF2 file")

    args = parser.parse_args()

    app_bin = args.app.replace(".elf", ".bin")

    print(f"Converting {args.app} to {app_bin}...")
    convert_elf_to_bin(args.objcopy, args.app, app_bin)

    with open(app_bin, "rb") as f:
        fw_content = f.read()

    bit_content = b""
    if args.bitstream and os.path.exists(args.bitstream):
        print(f"Adding bitstream from {args.bitstream}...")
        with open(args.bitstream, "rb") as f:
            bit_content = f.read()
    elif args.bitstream:
        print(f"Warning: Bitstream {args.bitstream} provided but not found")

    fw_blocks = (len(fw_content) + 255) // 256
    bit_blocks = (len(bit_content) + 255) // 256
    total_blocks = fw_blocks + bit_blocks

    APP_ADDRESS = 0x08010000
    FPGA_ADDRESS = 0x09000000

    UF2_MAGIC_START0 = 0x0A324655
    UF2_MAGIC_START1 = 0x9E5D5157
    UF2_MAGIC_END = 0x0AB16F30
    FAMILY_ID_STM32F4 = 0x57755A57
    FLAGS = 0x00002000

    print(f"Generating {args.output}...")
    with open(args.output, "wb") as f:

        def write_block(data, addr, blockno):
            hd = struct.pack(
                "<IIIIIIII",
                UF2_MAGIC_START0,
                UF2_MAGIC_START1,
                FLAGS,
                addr,
                256,
                blockno,
                total_blocks,
                FAMILY_ID_STM32F4,
            )
            data_padded = data + b"\x00" * (476 - len(data))
            ft = struct.pack("<I", UF2_MAGIC_END)
            f.write(hd + data_padded + ft)

        # Write Firmware
        for i in range(fw_blocks):
            ptr = 256 * i
            chunk = fw_content[ptr : ptr + 256]
            write_block(chunk, APP_ADDRESS + ptr, i)

        # Write Bitstream
        for i in range(bit_blocks):
            ptr = 256 * i
            chunk = bit_content[ptr : ptr + 256]
            write_block(chunk, FPGA_ADDRESS + ptr, fw_blocks + i)

    print(f"Successfully created {args.output}")


if __name__ == "__main__":
    main()
