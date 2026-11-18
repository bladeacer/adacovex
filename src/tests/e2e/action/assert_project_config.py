#!/usr/bin/env python3
"""Assert that the action honoured the target's `adacovex.toml`.

The `action-project-config` CI job runs the composite action against
`src/tests/projects/action-project-config/`, whose project file sets
`[prove] level = 1` and `coverage = false`. The action tees the proof log; this
script reads that log and checks both effects, so the job never relies on an
inline grep with a developer command in it.

Usage:
  python3 src/tests/e2e/action/assert_project_config.py PATH_TO_LOG

Exit code 0 when both settings reached the run, 1 otherwise.
"""

import sys
from pathlib import Path
from typing import List


def main(argv: List[str]) -> int:
    """Check one proof log and return the exit code.

    @param argv  Command-line arguments (the log path follows the program).
    @return 0 when the project configuration took effect, 1 otherwise.
    """
    if len(argv) != 2:
        print("usage: assert_project_config.py LOG", file=sys.stderr)
        return 2
    log = Path(argv[1])
    if not log.is_file():
        print(f"error: proof log not found: {log}", file=sys.stderr)
        return 1
    text = log.read_text(encoding="utf-8", errors="replace")
    failed = 0
    if "--level 1" not in text:
        print("::error::[prove] level = 1 was not honoured through the action",
              file=sys.stderr)
        failed = 1
    if "coverage:" in text:
        print("::error::[prove] coverage = false was not honoured through "
              "the action", file=sys.stderr)
        failed = 1
    if "Success: all checks proved" not in text:
        print("::error::the fixture did not prove", file=sys.stderr)
        failed = 1
    if failed == 0:
        print("Action project configuration: level 1 and coverage off "
              "reached the prove run.")
    return failed


if __name__ == "__main__":
    sys.exit(main(sys.argv))
