#!/usr/bin/env python3
"""End-to-end CLI tests for the adacovex shorthands, aliases, and tier tokens.

The Playwright suite (src/tests/e2e/dashboard/tests/dashboard.spec.ts)
covers the served dashboard.  This runner covers the command line itself:
the check groups live in `checks_basic`, `checks_sbom`, `checks_serve`,
`checks_config`, and `checks_prove`, and `CHECKS` is the one registry.

It needs no browser and no third-party package, so it runs anywhere the
binary is built:

  just build          # once
  python3 src/tests/e2e/cli/cli_flags.py

Exit code 0 when every check passes or skips (a skip is reported with its
reason and is never counted as a pass), 1 when a check fails.
"""

import argparse
import sys
import tempfile
from pathlib import Path

from cli_support import BIN, Results
from checks_basic import (check_completion, check_help, check_rejections,
                          check_tier_tokens, check_version)
from checks_config import (check_complexity, check_config_files,
                           check_config_prove, check_init,
                           check_spark_coverage, check_timezone)
from checks_prove import (check_differential, check_differential_regression,
                          check_prove, check_tldr_install)
from checks_sbom import (check_markdown_output, check_sbom_shapes,
                         check_sbom_siblings, check_target_equivalence)
from checks_serve import (check_serve_info_health, check_serve_shorthands,
                          check_serve_watch, check_theme_and_port)

#  Named check groups.  Each group owns its project subdirectories under a
#  private temporary root, so the groups can run as separate shards.
CHECKS = [
    ("version", lambda r, tmp: check_version(r)),
    ("help", lambda r, tmp: check_help(r)),
    ("completion", lambda r, tmp: check_completion(r)),
    ("rejections", lambda r, tmp: check_rejections(r)),
    ("tier tokens", check_tier_tokens),
    ("SBOM shapes", check_sbom_shapes),
    ("SBOM siblings", check_sbom_siblings),
    ("target equivalence", check_target_equivalence),
    ("markdown output", check_markdown_output),
    ("complexity", check_complexity),
    ("init", check_init),
    ("config files", check_config_files),
    ("config prove", check_config_prove),
    ("spark coverage", check_spark_coverage),
    ("timezone", check_timezone),
    ("differential", check_differential),
    ("differential regression", check_differential_regression),
    ("prove", check_prove),
    ("serve shorthands", check_serve_shorthands),
    ("serve info/health", check_serve_info_health),
    ("serve watch", check_serve_watch),
    ("theme and port", check_theme_and_port),
    ("tldr install", check_tldr_install),
]


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--shard", default="0/1",
        help="run one slice of the checks, as INDEX/COUNT")
    args = parser.parse_args(argv)
    try:
        index_text, count_text = args.shard.split("/", 1)
        index, count = int(index_text), int(count_text)
    except ValueError:
        print(f"error: invalid --shard '{args.shard}' (use INDEX/COUNT)",
              file=sys.stderr)
        return 2
    if count < 1 or not 0 <= index < count:
        print(f"error: shard {args.shard} is out of range", file=sys.stderr)
        return 2
    if not Path(BIN).is_file():
        print(f"error: {BIN} not found; run `just build` first",
              file=sys.stderr)
        return 1
    selected = CHECKS[index::count]
    r = Results()
    print(f"=== adacovex CLI end-to-end checks (shard {index + 1}/{count}) "
          "===")
    with tempfile.TemporaryDirectory(prefix="adacovex-cli-e2e-") as td:
        tmp = Path(td)
        for _, check in selected:
            check(r, tmp)
    return r.report("CLI E2E")


if __name__ == "__main__":
    sys.exit(main())
