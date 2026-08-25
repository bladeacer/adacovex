#!/usr/bin/env python3
"""Print the binary-size report for `make bench`.

The old bench recipe counted bytes with GNU-only `stat -c %s` and formatted
them with inline awk one-liners whose double-quote/backslash escaping broke
under some shells ("backslash not last character on line").  This script
stats the files and formats the report in plain Python:

  python3 tools/bench-size.py <raw-binary> <stripped-binary>

Exit code 0 on success.  A missing file or a negative savings ratio exits 1.
"""

import argparse
import sys
from pathlib import Path
from typing import Tuple

MIB: float = 1048576.0


def human_mib(size: int) -> str:
    return f"{size / MIB:6.1f} MiB"


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("raw", metavar="RAW_BINARY",
                        help="path to bin/adacovex")
    parser.add_argument("stripped", metavar="STRIPPED_BINARY",
                        help="path to the stripped copy")
    return parser.parse_args(argv)


def file_size(path: str) -> int:
    try:
        return Path(path).stat().st_size
    except OSError as exc:
        print(f"error: cannot stat {path}: {exc}", file=sys.stderr)
        raise SystemExit(1)


def main() -> int:
    args = parse_args(sys.argv[1:])
    raw = file_size(args.raw)
    stripped = file_size(args.stripped)
    if raw <= 0 or stripped <= 0:
        print("error: binary sizes must be positive", file=sys.stderr)
        return 1
    if stripped > raw:
        print("error: stripped size cannot exceed the raw size", file=sys.stderr)
        return 1
    savings: float = (raw - stripped) / raw * 100.0
    print(f"bin/adacovex          {human_mib(raw)}  ({raw} bytes)")
    print(f"after strip           {human_mib(stripped)}  ({stripped} bytes)")
    print(f"savings               {savings:5.1f}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())