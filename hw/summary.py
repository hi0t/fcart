import sys
import re


class bcolors:
    HEADER = "\033[95m"
    WARNING = "\033[93m"
    ENDC = "\033[0m"


if __name__ == "__main__":
    log_file = sys.argv[1]

    with open(log_file, "r") as f:
        lines = f.readlines()

    usage = []
    for line in lines:
        line = line.strip()
        if (
            line.startswith("Number of LUT4s:")
            or line.startswith("Number of registers:")
            or line.startswith("Number of block RAMs:")
        ):
            usage.append(line)

    print(bcolors.HEADER)
    print("Usage summary")
    print("*************")
    print(bcolors.ENDC)

    max_len = 0
    for u in usage:
        parts = u.split(":")
        if len(parts) >= 2:
            max_len = max(max_len, len(parts[0].strip() + ":"))

    for u in usage:
        parts = u.split(":")
        if len(parts) >= 2:
            label = parts[0].strip() + ":"
            print(f"  {label.ljust(max_len)} {parts[1].strip()}")
        else:
            print(f"  {u}")

    twr_file = sys.argv[2]
    timings = []
    curr_parts = {}
    state = 0
    skip = 4
    with open(twr_file, "r") as f:
        for line in f:
            if state == 0:
                if "Report Summary" in line:
                    state = 1
                continue

            if state == 1:
                if skip > 0:
                    skip -= 1
                    continue
                else:
                    state = 2

            if state == 2:
                if line.strip().startswith("---"):
                    break

                if "|" in line:
                    parts = line.split("|")

                    if not parts[0].strip():
                        if curr_parts:
                            timings.append(curr_parts)
                            curr_parts = {}
                        continue

                    if curr_parts:
                        curr_parts["preference"] += parts[0].strip()
                        curr_parts["constraint"] += parts[1].strip()
                        curr_parts["actual"] += parts[2].strip()
                        curr_parts["levels"] += parts[3].strip()
                    else:
                        curr_parts = {
                            "preference": parts[0].strip(),
                            "constraint": parts[1].strip(),
                            "actual": parts[2].strip(),
                            "levels": parts[3].strip(),
                        }

    print(bcolors.HEADER)
    print("Timing summary")
    print("**************")
    print(bcolors.ENDC, end="")

    column_widths = [max(len(str(item)) + 4 for item in col) for col in zip(*timings)]

    for i, t in enumerate(timings):
        if t["constraint"] == "-":
            continue

        if t["levels"].endswith("*"):
            print(f"{bcolors.WARNING}", end="")

        preference = re.findall(r'"([^"]*)"', t["preference"])
        print(
            f"  {(preference[0]+":").ljust(column_widths[0])}{t['constraint'].ljust(column_widths[1])}{t['actual'].ljust(column_widths[2])}",
            end="",
        )
        print(f"{bcolors.ENDC}")

    print()
