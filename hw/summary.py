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
        if line.startswith("WARNING - map:"):
            warnings.append(line)
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
    skip = False
    capture = 0
    for line in lines:
        line = line.rstrip()

        if line.startswith("Report Summary"):
            skip = True
            continue

        if skip:
            skip = False
            capture = 3
            continue

        if capture > 0:
            timings.append(line)
            capture -= line.startswith("-" * 10)
            if capture == 0:
                break

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

