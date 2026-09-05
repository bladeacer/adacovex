#!/usr/bin/env python3
"""Check the GitHub Action mirrors the base CLI option set (feature gate).

Per AGENTS.md "GitHub Action = base-CLI feature parity", the composite action
(`action.yml`) must mirror the base CLI option set so CI can drive every
assessment feature the same way the binary does.  This script is the gate
that enforces the rule -- it fails when a CLI flag, action input, or
docs/usage/ci-cd.md table row drifts out of sync:

- every CLI flag (except the documented early-exit / dashboard / subcommand
  flags) has a matching action input;
- every action input (except the documented CI-plumbing inputs) maps back to
  a CLI flag;
- every action input is documented in the docs/usage/ci-cd.md `### Inputs` table
  and every row in that table is a real input.

Sources of truth:

- CLI flags: the `Known_Flags` constant in src/core/adacovex-config.adb
  (the same list the "did you mean" suggestion walks, so Parse_Args and this
  gate share one definition);
- action inputs: the top-level `inputs:` section of action.yml;
- documentation: the `### Inputs` table in docs/usage/ci-cd.md.

Mapping rules:

- a flag with the same name as an input maps 1:1 (`--target` -> `target`);
- prove-mode flags map to `prove-<flag>` inputs (`--jobs` -> `prove-jobs`,
  `--quiet` -> `prove-quiet`), except `--force` which is `prove-force`;
- `--no-sbom` is the inverted form of the `generate-sbom` input
  (`generate-sbom: false` == `--no-sbom`);
- `--format` is the CLI alias of `--sbom-format` (the action exposes only
  `sbom-format`).

When adding a CLI flag: add the matching action input (and its docs/usage/ci-cd.md
row) -- or, only when the flag is genuinely not CI-driveable (early-exit
`--help`/`--version`, local dashboard `--serve`/`--theme`/`--port`,
subcommands `status`/`man`/`sbom`, or the `--out`/`--emit-svg` output
paths), add it to CLI_ONLY below with a reason.  Adding an action input
without the matching CLI flag or docs row fails here too.

Usage:
  python3 tools/check-action-parity.py   # check; exit 1 on any drift
  python3 tools/check-action-parity.py --sources  # print the parsed sets
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Set

ROOT: Path = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# Expected mapping tables (the single source of truth for the parity rule).
# ---------------------------------------------------------------------------

# CLI flags that intentionally have NO action input.  Keep this list to the
# genuinely non-CI flags only; anything else must be wired into action.yml
# and docs/usage/ci-cd.md instead of listed here.
CLI_ONLY: Dict[str, str] = {
    "help": "early-exit --help",
    "version": "early-exit --version (the action's `version` input is the release ref, not this flag)",
    "serve": "dashboard serve flag (local only)",
    "serve-workers": "dashboard server worker count (local only)",
    "theme": "dashboard theme flag (local only)",
    "port": "dashboard server port (local only)",
    "tz": "display timezone override (local diagnostics)",
    "timezone": "display timezone override (alias of --tz; local diagnostics)",
    "excludes": "complexity --excludes extension skip (local quality gate)",
    "skip-path": "complexity --skip-path per-path exclusion (local quality gate)",
    "emit-svg": "SVG badge output path (CI uses the default <target>/docs/badges)",
    "cache": "result-cache enable is default-on; the action exposes only the negative --no-cache",
    "sbom": "sbom subcommand; the action drives SBOM via generate-sbom + sbom-format inputs",
    "status": "status subcommand (local diagnostics)",
    "export": "status --export JSON output selector (local diagnostics)",
    "metrics": "status --metrics key=value output selector (local diagnostics)",
    "completion": "shell completion subcommand (local shell setup)",
    "man": "man subcommand (local install)",
    "check": "man --check (local)",
    "dir": "man --dir (local)",
    "out": "sbom --out output path (the action uploads the SBOM artifact itself)",
    "complexity": "complexity subcommand (local quality gate; wired into make complexity-check)",
}

# Action inputs that intentionally have NO CLI flag (CI plumbing that drives
# the action itself, not the assessed binary).
ACTION_ONLY: Dict[str, str] = {
    "gnat-version": "Alire toolchain selection (not a CLI flag)",
    "version": "adacovex release ref for the action itself (not the --version flag)",
    "build": "build-from-source vs download toggle (not a CLI flag)",
    "run-tests": "runs the target's native test suite (not a CLI flag)",
    "test-command": "test command override (not a CLI flag)",
    "release-build": "passes --release to alr build (not a CLI flag)",
    "assess": "assessment-step toggle (not a CLI flag)",
    "result-cache": "GitHub actions/cache persistence of ~/.adacovex/cache (not a CLI flag)",
    "cache": "GitHub actions/cache for the Alire toolchain (not the CLI --cache flag)",
}

# CLI flags whose action input carries a prove- prefix (prove-mode flags).
PROVE_PREFIXED: Set[str] = {
    "jobs",
    "level",
    "timeout",
    "steps",
    "memlimit",
    "force",
    "no-loop-unrolling",
    "no-inlining",
    "suppress-warnings",
    "quiet",
    "args",
}

# CLI flag -> differently-named action input (inverted / alias forms).
CLI_TO_INPUT: Dict[str, str] = {
    "no-sbom": "generate-sbom",  # generate-sbom: false == --no-sbom
    "format": "sbom-format",     # --format is the alias of --sbom-format
}


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def cli_flags() -> Set[str]:
    """Extract the CLI flag names from Known_Flags in adacovex-config.adb."""
    path: Path = ROOT / "src" / "core" / "adacovex-config.adb"
    text: str = path.read_text(encoding="utf-8")
    m = re.search(r"Known_Flags : constant String :=\s*(.*?);", text, re.S)
    if m is None:
        raise SystemExit(f"  ERROR: Known_Flags not found in {path}")
    block: str = "".join(re.findall(r'"([^"]*)"', m.group(1)))
    return set(block.split())


def action_inputs() -> Set[str]:
    """Extract the input names from the top-level `inputs:` section of
    action.yml (input keys sit at exactly two-space indent; nested keys like
    description/required/default sit at four)."""
    path: Path = ROOT / "action.yml"
    text: str = path.read_text(encoding="utf-8")
    lines: List[str] = text.splitlines()
    names: Set[str] = set()
    in_inputs: bool = False
    for line in lines:
        if line.startswith("inputs:"):
            in_inputs = True
            continue
        if in_inputs and re.match(r"^[a-z]", line):
            in_inputs = False  # next top-level key (outputs:, runs:, ...)
        if in_inputs:
            m = re.match(r"^  ([a-z0-9-]+):$", line)
            if m:
                names.add(m.group(1))
    return names


def docs_inputs() -> Set[str]:
    """Extract the input names from the docs/usage/ci-cd.md `### Inputs` table."""
    path: Path = ROOT / "docs" / "usage" / "ci-cd.md"
    text: str = path.read_text(encoding="utf-8")
    m = re.search(r"### Inputs\n(.*?)(?:^### |\Z)", text, re.M | re.S)
    if m is None:
        raise SystemExit(f"  ERROR: `### Inputs` table not found in {path}")
    return set(re.findall(r"^\| `([a-z0-9-]+)` \|", m.group(1), re.M))


# ---------------------------------------------------------------------------
# Mapping helpers
# ---------------------------------------------------------------------------

def expected_input(flag: str) -> str:
    """The action input that should drive the given CLI flag."""
    if flag in CLI_TO_INPUT:
        return CLI_TO_INPUT[flag]
    if flag in PROVE_PREFIXED:
        return "prove-" + flag
    return flag


def expected_flag(inp: str) -> str:
    """The CLI flag an action input should map back to."""
    if inp == "generate-sbom":
        return "no-sbom"
    if inp == "sbom-format":
        return "sbom-format"  # both --sbom-format and its alias --format map here
    if inp.startswith("prove-"):
        return inp[len("prove-"):]
    return inp


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

def check() -> int:
    errors: List[str] = []
    cli: Set[str] = cli_flags()
    inputs: Set[str] = action_inputs()
    docs: Set[str] = docs_inputs()

    # 1. Every CLI flag (except documented CLI_ONLY) has a matching input.
    for flag in sorted(cli):
        if flag in CLI_ONLY:
            continue
        if expected_input(flag) not in inputs:
            errors.append(
                f"CLI flag `--{flag}` has no action input "
                f"(expected `{expected_input(flag)}`). Add the input + "
                f"docs/usage/ci-cd.md row, or document the flag in CLI_ONLY.")

    # 2. Every action input (except documented ACTION_ONLY) maps back to a
    #    CLI flag.
    for inp in sorted(inputs):
        if inp in ACTION_ONLY:
            continue
        if expected_flag(inp) not in cli:
            errors.append(
                f"action input `{inp}` has no CLI flag "
                f"(`--{expected_flag(inp)}` not in Known_Flags). Add the "
                f"flag, or document the input in ACTION_ONLY.")

    # 3. Every action input is documented in docs/usage/ci-cd.md and vice versa.
    for inp in sorted(inputs):
        if inp not in docs:
            errors.append(
                f"action input `{inp}` is missing from the docs/usage/ci-cd.md "
                f"`### Inputs` table.")
    for doc in sorted(docs):
        if doc not in inputs:
            errors.append(
                f"docs/usage/ci-cd.md lists `{doc}`, which is not an action input "
                f"in action.yml.")

    if errors:
        for e in errors:
            print(f"  ERROR: {e}")
        print(f"  Action/CLI/docs parity check FAILED ({len(errors)} error(s))")
        return 1

    print(f"  CLI flags: {len(cli)} | action inputs: {len(inputs)} | "
          f"docs inputs: {len(docs)}")
    print("  Action/CLI/docs parity check passed.")
    return 0


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--sources",
        action="store_true",
        help="print the parsed CLI-flag / action-input / docs-input sets",
    )
    args: argparse.Namespace = ap.parse_args(argv)
    if args.sources:
        print(f"CLI flags: {sorted(cli_flags())}")
        print(f"Action inputs: {sorted(action_inputs())}")
        print(f"Docs inputs: {sorted(docs_inputs())}")
        return 0
    return check()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
