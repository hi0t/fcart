import argparse


def binary_to_lattice_mem(input_filepath, output_filepath):
    with open(input_filepath, "rb") as infile:
        with open(output_filepath, "w") as outfile:
            while byte := infile.read(1):
                outfile.write("{:02x}\n".format(byte[0]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert binary file to Lattice .mem format"
    )
    parser.add_argument("input", help="Input binary file path")
    parser.add_argument("output", help="Output .mem file path")
    args = parser.parse_args()
    binary_to_lattice_mem(args.input, args.output)
