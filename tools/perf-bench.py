#!/usr/bin/env python3
"""Performance benchmarking helper for adacovex.

Runs the adacovex binary under perf and strace to collect cache-miss and
system-call profiles, then prints a summary.  Requires:
  * linux-tools-common (perf)
  * strace

Usage:
  python3 tools/perf-bench.py [--target=PATH] [--runs=N]
"""
import argparse
import subprocess
import sys
from pathlib import Path


def run(cmd, description):
    print(f"=== {description} ===")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"WARNING: {cmd} failed (rc={result.returncode})")
        if result.stderr:
            print(result.stderr)
    else:
        print(result.stdout)
    print()


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", default=".", help="Target project path")
    parser.add_argument("--runs", type=int, default=3, help="Sample size")
    parser.add_argument(
        "--binary",
        default="bin/adacovex",
        help="Path to the adacovex binary",
    )
    args = parser.parse_args(argv)

    root = Path(__file__).resolve().parent.parent
    binary = root / args.binary
    if not binary.exists():
        print(f"error: {binary} not found; run make build first")
        return 1

    target_arg = f"--target={args.target}"
    cmd_base = f"{binary} --cache-dir=/tmp/adacovex-perf-cache {target_arg}"

    print(f"Benchmarking: {cmd_base}")
    print(f"Sample size: {args.runs} runs per tool")
    print()

    for i in range(1, args.runs + 1):
        run(
            f"perf stat -e cache-references,cache-misses,L1-dcache-loads,L1-dcache-load-misses {cmd_base}",
            f"perf run {i}/{args.runs}",
        )

    for i in range(1, args.runs + 1):
        run(
            f"strace -c -f {cmd_base} 2>&1 | tail -20",
            f"strace run {i}/{args.runs}",
        )

    print("=== Summary ===")
    print("Review the cache-miss rates above.  L1 dcache load-miss rates above")
    print("~5%% typically indicate room for data-layout improvements.")
    print("Review the strace syscall counts for unexpected I/O or context switches.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
