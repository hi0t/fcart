#!/usr/bin/env python3
import sys
import subprocess
import os
from pathlib import Path

# The script is located in hw/docker/
# The compose file is in the same directory
SCRIPT_DIR = Path(__file__).parent.resolve()
COMPOSE_FILE = SCRIPT_DIR / "compose.yml"


def main():
    if len(sys.argv) < 3:
        print("Usage: docker_cmd.py <service> <command...>", file=sys.stderr)
        sys.exit(1)

    service = sys.argv[1]
    # The rest of the arguments are the command and its parameters
    command_args = sys.argv[2:]

    # Build the docker compose command
    # Use -T to disable pseudo-tty allocation (important for build systems)
    # Use --rm to remove the container after execution
    docker_cmd = [
        "docker",
        "compose",
        "-f",
        str(COMPOSE_FILE),
        "run",
        "--rm",
        "-T",
        service,
    ] + command_args

    # Run the command, passing the current environment (to preserve variables like USER)
    try:
        result = subprocess.run(docker_cmd)
        sys.exit(result.returncode)
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as e:
        print(f"Error running docker wrapper: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
