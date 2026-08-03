#!/usr/bin/env python3
"""Generate the AGENTS.md source-tree block for adacovex.

Renders the src/ directory as an ASCII tree with .ads/.adb pairs grouped
on one line, annotated with a per-file purpose from tools/agents-tree.map.
Any src file missing from the map is flagged (exit 1) so the map stays in
sync with the source tree.  Output goes to stdout.

Usage: python3 tools/gen-agents-tree.py
"""

import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "src")
MAP = os.path.join(ROOT, "tools", "agents-tree.map")


def load_map():
    purposes = {}
    with open(MAP, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            rel, _, purpose = line.partition("\t")
            purposes[rel] = purpose.strip()
    return purposes


def collect():
    """Return dict: dirpath -> sorted list of stems (with purpose)."""
    nodes = {}
    for dirpath, dirnames, filenames in os.walk(SRC):
        dirnames.sort()
        rel = os.path.relpath(dirpath, SRC)
        if rel == ".":
            rel = ""
        entry = {}
        for fn in filenames:
            if fn.endswith(".ads") or fn.endswith(".adb"):
                stem = fn[:-4]
                if stem not in entry:
                    entry[stem] = {"ads": False, "adb": False}
                if fn.endswith(".ads"):
                    entry[stem]["ads"] = True
                else:
                    entry[stem]["adb"] = True
        nodes[rel] = entry
    return nodes


def stem_rel(root, rel, stem):
    if rel:
        return "src/" + rel.replace(os.sep, "/") + "/" + stem
    return "src/" + stem


def main():
    purposes = load_map()
    nodes = collect()

    missing = []
    for rel, entry in nodes.items():
        for stem in entry:
            rel_path = stem_rel(SRC, rel, stem)
            if rel_path not in purposes:
                missing.append(rel_path)

    # Files in the map that no longer exist in src/
    stale = []
    known = set()
    for rel, entry in nodes.items():
        for stem in entry:
            known.add(stem_rel(SRC, rel, stem))
    for rel_path in purposes:
        if rel_path not in known and os.path.exists(
            os.path.join(ROOT, rel_path.replace("/", os.sep) + ".ads")
        ) is False and os.path.exists(
            os.path.join(ROOT, rel_path.replace("/", os.sep) + ".adb")
        ) is False:
            stale.append(rel_path)

    if missing or stale:
        for p in missing:
            print(f"  MISSING PURPOSE: {p} (add to tools/agents-tree.map)", file=sys.stderr)
        for p in stale:
            print(f"  STALE MAP ENTRY: {p} (no such file; remove from map)", file=sys.stderr)
        return 1

    rels = sorted(nodes, key=lambda r: (r == "", r))

    def render_dir(prefix, rel, force_not_last=False):
        entry = nodes[rel]
        stems = sorted(entry)
        for i, stem in enumerate(stems):
            last = (not force_not_last) and i == len(stems) - 1
            connector = "`-- " if last else "|-- "
            name = stem
            if entry[stem]["ads"] and entry[stem]["adb"]:
                name += ".ads/.adb"
            elif entry[stem]["ads"]:
                name += ".ads"
            else:
                name += ".adb"
            rel_path = stem_rel(SRC, rel, stem)
            purpose = purposes.get(rel_path, "")
            yield prefix + connector + name + " " * (46 - len(prefix) - len(connector) - len(name)) + "-- " + purpose

    lines = ["src/"]
    # Root-level files first (matching the original AGENTS.md layout),
    # then subdirectories.
    for line in render_dir("", "", force_not_last=True):
        lines.append(line)

    subdirs = [r for r in rels if r != ""]
    for idx, rel in enumerate(subdirs):
        is_last_dir = idx == len(subdirs) - 1
        top_connector = "`-- " if is_last_dir else "|-- "
        lines.append(top_connector + rel.replace(os.sep, "/") + "/")
        child_prefix = "    " if is_last_dir else "|   "
        lines.extend(render_dir(child_prefix, rel))

    for line in lines:
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
