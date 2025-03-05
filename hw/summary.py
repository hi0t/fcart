import sys

class bcolors:
    HEADER = '\033[95m'
    WARNING = '\033[93m'
    ENDC = '\033[0m'

if __name__ == "__main__":
    log_file = sys.argv[1]

    with open(log_file, 'r') as f:
        lines = f.readlines()

    warnings = []
    usage = []
    for line in lines:
        line = line.strip()
        if line.startswith("@W:"):
            warnings.append(line[4:])
        if line.startswith("Number of LUT4s:") or line.startswith("Number of registers:"):
            usage.append(line)

    if len(warnings) > 0:
        print(bcolors.WARNING)
        for w in warnings:
            print(f"  {w}")
        print(bcolors.ENDC, end='')

    print(bcolors.HEADER)
    print("Usage summary")
    print("*************")
    print(bcolors.ENDC, end='')
    for u in usage:
        print(f"  {u}")

    twr_file = sys.argv[2]

    with open(twr_file, 'r') as f:
        lines = f.readlines()

    timings = []
    capture = 0
    skip = 0
    for line in lines:
        if skip > 0:
            skip -= 1
            continue

        line = line.rstrip()

        if capture > 0:
            capture -= 1
            timings.append(line)
            if capture == 0:
                break
            else:
                continue

        if line.startswith("Report Summary"):
            capture = 7
            skip = 1

    print(bcolors.HEADER)
    print("Timing summary")
    print("**************")
    print(bcolors.ENDC, end='')

    for t in timings:
        if t.endswith("*"):
            print(f"{bcolors.WARNING}{t}{bcolors.ENDC}")
        else:
            print(t)

    print()

