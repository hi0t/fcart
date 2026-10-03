#!/usr/bin/env python3

import argparse
import os
import struct
import subprocess
import sys


def run_command(cmd, cwd=None):
    result = subprocess.run(cmd, check=False, shell=True, cwd=cwd)
    if result.returncode != 0:
        print(f"Error executing command: {cmd}")
        sys.exit(1)


def convert_elf_to_bin(objcopy, elf_path, bin_path):
    run_command(f"{objcopy} -O binary {elf_path} -S {bin_path}")


def parse_jed_file(jed_path):
    with open(jed_path, "r", encoding="utf-8", errors="ignore") as f:
        jed_content = f.read()

    stx_pos = jed_content.find("\x02")
    body = jed_content[stx_pos:] if stx_pos != -1 else jed_content
    tokens = body.split("*")
    prev_note = ""
    cfg_lines = []
    ebr_lines = []
    feat_bytes = None
    fea_bytes = None

    for tok in tokens:
        tok = tok.strip()
        if not tok:
            continue
        if tok.startswith(("NOTE ", "N ")):
            prev_note = tok.split(None, 1)[1].strip()
        elif tok.startswith("E"):
            lines = tok.split()
            feature_row_str = lines[0][1:]  # strip leading 'E'
            feabits_str = lines[1]

            # In JEDEC files and Lattice MachXO2 sysCONFIG SPI (MSB-first on MOSI):
            # The characters in JED string are in MSB-first order for each byte.
            feat_bytes = bytes(
                int(feature_row_str[i : i + 8], 2)
                for i in range(0, len(feature_row_str), 8)
            )
            fea_bytes = bytes(
                int(feabits_str[i : i + 8], 2) for i in range(0, len(feabits_str), 8)
            )
            print(f"Parsed Feature Row: {feat_bytes.hex()}, FEAbits: {fea_bytes.hex()}")
        elif tok.startswith("L"):
            lines = tok.splitlines()
            data_lines = [l.strip() for l in lines[1:] if l.strip()]
            if not data_lines:
                parts = tok.split()
                data_lines = parts[1:]
            if prev_note == "END CONFIG DATA":
                continue
            elif prev_note == "EBR_INIT DATA":
                ebr_lines.extend(data_lines)
            elif prev_note == "TAG DATA":
                continue
            else:
                cfg_lines.extend(data_lines)

    def to_bytes(lines):
        b = bytearray()
        for l in lines:
            for i in range(0, len(l), 8):
                b.append(int(l[i : i + 8], 2))
        return bytes(b)

    cfg_payload = to_bytes(cfg_lines + ebr_lines)
    features_payload = (feat_bytes or (b"\x00" * 8)) + (fea_bytes or (b"\x00" * 2))
    print(
        f"Parsed {len(cfg_lines)} CFG + {len(ebr_lines)} EBR lines -> "
        f"{len(cfg_payload)} bytes ({len(cfg_payload) // 16} pages)"
    )
    return cfg_payload, features_payload


def main():
    parser = argparse.ArgumentParser(description="Generate UF2 firmware")
    parser.add_argument("--app", required=True, help="Path to application ELF")
    parser.add_argument("--objcopy", required=True, help="Path to objcopy tool")
    parser.add_argument("--jed", required=True, help="Path to FPGA JEDEC file")
    parser.add_argument("-o", "--output", required=True, help="Output UF2 file")

    args = parser.parse_args()

    app_bin = args.app.replace(".elf", ".bin")

    print(f"Converting {args.app} to {app_bin}...")
    convert_elf_to_bin(args.objcopy, args.app, app_bin)

    with open(app_bin, "rb") as f:
        fw_content = f.read()

    bit_content = b""
    fea_content = b""
    if os.path.exists(args.jed):
        print(f"Parsing configuration pages and features from {args.jed}...")
        bit_content, fea_content = parse_jed_file(args.jed)
    else:
        print(f"Warning: JED file {args.jed} provided but not found")

    fw_blocks = (len(fw_content) + 255) // 256
    bit_blocks = (len(bit_content) + 255) // 256
    fea_blocks = (len(fea_content) + 255) // 256
    total_blocks = fw_blocks + bit_blocks + fea_blocks

    APP_ADDRESS = 0x08010000
    FPGA_ADDRESS = 0x09000000
    FPGA_FEABITS_ADDRESS = 0x09100000

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

        block_no = 0

        # Write Firmware
        for i in range(fw_blocks):
            ptr = 256 * i
            chunk = fw_content[ptr : ptr + 256]
            write_block(chunk, APP_ADDRESS + ptr, block_no)
            block_no += 1

        # Write Bitstream
        for i in range(bit_blocks):
            ptr = 256 * i
            chunk = bit_content[ptr : ptr + 256]
            write_block(chunk, FPGA_ADDRESS + ptr, block_no)
            block_no += 1

        # Write FEAbits
        for i in range(fea_blocks):
            ptr = 256 * i
            chunk = fea_content[ptr : ptr + 256]
            write_block(chunk, FPGA_FEABITS_ADDRESS + ptr, block_no)
            block_no += 1

    print(f"Successfully created {args.output}")


if __name__ == "__main__":
    main()
