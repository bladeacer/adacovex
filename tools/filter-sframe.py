#!/usr/bin/env python3
"""Filter the benign ld 2.44 SFrame message out of the build log.

The Alire GNAT toolchain's bundled ld emits

  error in ...(.sframe); no .sframe will be created

when it reads the .sframe section newer system binutils wrote into the
glibc startup objects; the link still succeeds.  The old `make build`
recipe filtered it with `sed -e '/\\.sframe); no \\.sframe will be
created/d'`.

Usage:
  python3 tools/filter-sframe.py <log-file>

Prints every line except the SFrame notice.  Exit code 0 always.
"""

import sys
from typing import List

MARKER = ".sframe); no .sframe will be created"


def filter_log(text: str) -> List[str]:
    return [line for line in text.splitlines() if MARKER not in line]


def main() -> None:
    if len(sys.argv) != 2:
        print(__doc__.splitlines()[0], file=sys.stderr)
        print("usage: python3 tools/filter-sframe.py <log-file>", file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
        text = f.read()
    print("\n".join(filter_log(text)))


if __name__ == "__main__":
    main()