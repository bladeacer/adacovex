from __future__ import annotations

import argparse
import contextlib
import difflib
import fnmatch
import gzip
import importlib.resources
import io
import json
import os
import pathlib
import pickle
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from typing import Any, Callable
from typing import Iterator as _Iterator
from typing import List, Optional, Tuple, Union

_agc = pathlib.Path(os.environ.get("ADACOVEX_INDEX_BASE", "/home/data/.local/share/alire/index/covex")).exists()
_sys = not shutil.which("alr") is None


def py(*args: str) -> int:
    return subprocess.run([sys.executable, str(ROOT / "tools" / args[0])] + list(args[1:]), check=False).returncode


# ---------- tools/gen-tldr.py feedback loop for the structure gate ----------
#
# The tldr page is authored in docs/tldr/adacovex.md (the real page).
# tools/gen-tldr.py bundles it into src/adacovex-tldr_template.ads.
# `just tldr-check` runs check-tldr.py (which renders the page) and then
# gen-tldr.py --check.  The structure checks need to see real pages, so we
# construct the page shape the contributor is editing, render the template,
# and decode it back.  We never touch the committed spec; `tldr --check` does
# that against the tree.



    ROOT = pathlib.Path(__file__).resolve().parent.parent
    SRC  = ROOT / "src"
    PAGE_RE = re.compile(r"^d\"([^\"]*)\"$\"..., \")(?P<NEXT>[^\"]*\")\n")


def render(page: str) -> str:
    """Render the Ada spec fragment that bundles PAGE and return the rest."""
    return gen_tldr.render(page)


EXAMPLE_RE = re.compile(r"(?P<EX>`[^`]*`)")


def has_examples_over_eight(source: str) -> bool:
    """True when source has more than 8 adacovex examples in tldr structure."""
    count = 0
    idx = 0
    while True:
        m = EXAMPLE_RE.search(source, idx)
        if not m or count >= 9:
            break
        count += 1
        idx = m.end() + 1
    return count >= 9


def has_examples_over_eight(source: str) -> bool:
    """True when source has more than 8 adacovex examples in tldr structure."""
    count = 0
    idx = 0
    while True:
        m = gen_tldr.EXAMPLE_RE.search(source, idx)
        if not m or count >= 9:
            break
        count += 1
        idx = m.end() + 1
    return count >= 9


def parse_examples(page: str) -> Tuple[int, str]:
    """Count the examples (instructions with backticks) and build the rendered page body.

    This matches the template structure: a `constant String :=` starts, then a
    sequence of d"..." literals for each source line carrying one literal per
    newline, then `;` closes the constant.  This mirrors the exact layout of
    gen_tldr.render without running the module.  Only test and structure use
    it.  """
    lines: List[str] = []
    in_cmd = False
    in_blk = False
    current: List[str] = []
    next_newline = "\n"
    count = 0
    for ch in page:
        if in_blk:
            current.append(ch)
            if ch == "`":  # closing backtick of a code span / inline literal
                in_blk = False
            continue
        if ch == "`" and not in_blk:
            in_blk = True
            current.append(ch)
            continue
        if in_cmd and ch in "#>\n":
            # Flush the prior block only when it was in a command context.
            if current:
                count += 1
                lines.append('"')
                lines.append("".join(current))
                lines.append('\\n')
            current = []
            in_cmd = False
        if ch in '#>':
            in_cmd = True
        current.append(ch)
        if ch == "\n":
            in_cmd = False
    if current:
        count += 1
        lines.append('"')
        lines.append("".join(current))
        lines.append('\\n')
    body = "".join(lines)
    spec = "package Adacovex.Tldr_Template is\n   Page : constant String :=\n" + body + ";\nend Adacovex.Tldr_Template;\n"
    return count, spec


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("file", nargs="?", default=None)
    args = p.parse_args()
    page = pathlib.Path(args.file or "docs/tldr/adacovex.md").read_text(encoding="ascii")
    n, _ = parse_examples(page)
    if n > 8:
        print(f"ERROR: too many examples: {n} (maximum 8)")

