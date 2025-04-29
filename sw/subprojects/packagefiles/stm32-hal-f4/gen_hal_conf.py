import re
import sys, getopt


if __name__ == "__main__":
    input = ''
    output = ''
    hal_callbacks = []

    try:
        opts, args = getopt.getopt(sys.argv[1:], "i:o:c:", ["input=", "output=", "hal_callbacks="])
    except getopt.GetoptError:
        print('gen_hal_conf.py --input=<input_file> --output=<output_file> --hal_callbacks=<hal_callbacks>')
        sys.exit(2)
    for opt, arg in opts:
        if opt in ("-i", "--input"):
            input = arg
        elif opt in ("-o", "--output"):
            output = arg
        elif opt in ("-c", "--hal_callbacks"):
            hal_callbacks = arg.split(",")

    with open(input, 'r') as f:
        lines = f.readlines()
    with open(output, 'w') as f:
        for line in lines:
            for c in hal_callbacks:
                patt = r"(#define\s+USE_HAL_{0}_REGISTER_CALLBACKS\s+)0".format(c.upper())
                line = re.sub(patt, r'\g<1>1', line)
            f.write(line)
