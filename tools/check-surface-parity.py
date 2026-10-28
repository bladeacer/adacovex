#!/usr/bin/env python3
"""Check the CLI self-description surfaces agree with each other and the README.

AGENTS.md calls the tldr page, the man page, the CLI reference, `--help`, and
the shell-completion scripts the surfaces that describe the CLI.  This script
turns the Release-1 audit (plan 1.1) into a feature gate next to
`tools/check-docs-coverage.py` and `tools/check-action-parity.py`:

- every reference surface (the `--help` usage block, the man page SYNOPSIS,
  and the CLI-reference usage fence) advertises exactly the subcommand set
  the parser accepts, and every subcommand or flag it shows is real (no stale
  command examples);
- every shell-completion subcommand list offers exactly that subcommand set;
- the tldr page is a deliberate subset (a cheat sheet), so it may show fewer
  subcommands than the reference surfaces, but never a stale one;
- the surfaces that describe what adacovex *is* (the tldr description, the
  `--help` footer, the man DESCRIPTION, and the AGENTS.md project blurb) carry
  the README tagline, so the one-sentence description cannot drift away from
  the README.

The README usage fence is deliberately not compared: it is a quick-start
subset that links to the full CLI reference, not a reference surface.

Sources of truth:

- subcommands: the bare-word parser branches (`elsif A = "word" then`) in
  src/core/adacovex-config.adb;
- flags: the `Known_Flags` constant in the same file (the list the
  docs-coverage gate reads);
- the tagline: the first paragraph under the `# adacovex` heading in
  README.md.

Usage:
  python3 tools/check-surface-parity.py   # check; exit 1 on any drift
  python3 tools/check-surface-parity.py --sources  # print the parsed sets
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

ROOT: Path = Path(__file__).resolve().parent.parent


def _config_text() -> str:
    path: Path = ROOT / "src" / "core" / "adacovex-config.adb"
    return path.read_text(encoding="utf-8")


def subcommands() -> Set[str]:
    """The subcommand set the parser's bare-word branches accept."""
    matches: List[str] = re.findall(r'elsif A = "([a-z][a-z0-9-]*)" then',
                                    _config_text())
    if not matches:
        raise SystemExit("  ERROR: no bare-word parser branches found")
    return set(matches)


def cli_flags() -> Set[str]:
    """The CLI flag names from Known_Flags in adacovex-config.adb."""
    text: str = _config_text()
    m = re.search(r"Known_Flags : constant String :=\s*(.*?);", text, re.S)
    if m is None:
        raise SystemExit("  ERROR: Known_Flags not found")
    block: str = "".join(re.findall(r'"([^\"]*)"', m.group(1)))
    return set(block.split())


def _normalize(text: str) -> str:
    """Collapse whitespace and case-fold so a wrapped sentence matches."""
    return re.sub(r"\s+", " ", text).strip().casefold()


def readme_tagline() -> str:
    """The README project description (first paragraph under `# adacovex`).

    The leading article is dropped so every surface may capitalise freely
    ("Zero-dependency ...") and the trailing full stop is dropped so the
    tagline matches as a substring wherever it is quoted.
    """
    text: str = (ROOT / "README.md").read_text(encoding="utf-8")
    m = re.search(r"^# adacovex[ \t]*\n+(.+?)(?=\n[ \t]*\n)", text,
                  re.M | re.S)
    if m is None:
        raise SystemExit("  ERROR: README.md has no tagline paragraph")
    para: str = " ".join(m.group(1).split())
    para = re.sub(r"^(A|An|The)\s+", "", para)
    return _normalize(para.rstrip(" .!?"))


def _string_literals(text: str) -> List[str]:
    return re.findall(r'"([^"]*)"', text)


def _usage_block(text: str) -> str:
    """The `--help` usage block: literals between Usage and Options."""
    literals: List[str] = _string_literals(text)
    try:
        start = next(i for i, lit in enumerate(literals)
                     if lit.startswith("Usage: adacovex"))
        end = next(i for i, lit in enumerate(literals) if lit == "Options:")
    except StopIteration:
        raise SystemExit("  ERROR: --help usage block not found")
    if end <= start:
        raise SystemExit("  ERROR: --help usage block is out of order")
    return "\n".join(literals[start + 1:end])


def _help_text() -> str:
    """Every string literal Print_Usage prints, for the tagline check."""
    text: str = _config_text()
    try:
        body = text[text.index("procedure Print_Usage"):
                    text.index("end Print_Usage;")]
    except ValueError:
        raise SystemExit("  ERROR: Print_Usage not found")
    return "\n".join(_string_literals(body))


def _advertised_subcommands(text: str) -> Set[str]:
    """The subcommands invoked as `adacovex <word>` in a usage surface."""
    return set(re.findall(r"\badacovex ([a-z][a-z0-9-]*)", text))


def _shown_flags(text: str) -> Set[str]:
    return set(re.findall(r"--([a-z][a-z0-9-]*)", text))


def man_synopsis() -> str:
    """The man page's SYNOPSIS roff source (between its section markers)."""
    text: str = (ROOT / "src" / "renderers" /
                 "adacovex-renderers-man.adb").read_text(encoding="utf-8")
    try:
        start = text.index('".SH SYNOPSIS"')
        end = text.index('".SH DESCRIPTION"', start)
    except ValueError:
        raise SystemExit("  ERROR: man SYNOPSIS/DESCRIPTION markers not found")
    return "\n".join(_string_literals(text[start:end]))


def man_description() -> str:
    """The man page's DESCRIPTION roff source (until the next section)."""
    text: str = (ROOT / "src" / "renderers" /
                 "adacovex-renderers-man.adb").read_text(encoding="utf-8")
    try:
        start = text.index('".SH DESCRIPTION"')
    except ValueError:
        raise SystemExit("  ERROR: man DESCRIPTION marker not found")
    m = re.compile(r'"\.SH [A-Z]').search(text, start + 1)
    end: int = m.start() if m else len(text)
    return "\n".join(_string_literals(text[start:end]))


def cli_reference_fence() -> str:
    """The usage fence of docs/usage/cli-reference.md."""
    path: Path = ROOT / "docs" / "usage" / "cli-reference.md"
    text: str = path.read_text(encoding="utf-8")
    m = re.search(r"## Usage[ \t]*\n+```.*?\n(.*?)```", text, re.S)
    if m is None:
        raise SystemExit("  ERROR: cli-reference usage fence not found")
    return m.group(1)


def tldr_page() -> str:
    path: Path = ROOT / "docs" / "tldr" / "adacovex.md"
    return path.read_text(encoding="ascii")


def tldr_description(page: str) -> str:
    for line in page.splitlines():
        if line.startswith(">"):
            return line.lstrip(">").strip()
    raise SystemExit("  ERROR: tldr page has no description line")


def tldr_examples(page: str) -> List[str]:
    """The backtick-wrapped command lines of the tldr page."""
    commands: List[str] = []
    for line in page.splitlines():
        m = re.fullmatch(r"`([^`]+)`", line.strip())
        if m is not None:
            commands.append(m.group(1))
    return commands


def completion_subsets() -> Dict[str, Set[str]]:
    """Each shell script's advertised subcommand list.

    A shell whose script has no subcommand list (currently none, but a
    flags-only generator would land here) is omitted rather than failing:
    the check compares lists that exist.
    """
    text: str = (ROOT / "src" / "core" /
                 "adacovex-completion.adb").read_text(encoding="utf-8")
    found: Dict[str, Set[str]] = {}
    m = re.search(r'local subs=""([^"]+)""', text)
    if m is None:
        raise SystemExit("  ERROR: bash subcommand list not found")
    found["bash"] = set(m.group(1).split())
    fish: List[Set[str]] = [set(m2.group(1).split())
                            for m2 in re.finditer(r"-a '([^']+)'", text)]
    if not fish:
        raise SystemExit("  ERROR: fish subcommand list not found")
    found["fish"] = fish[0]
    if any(s != fish[0] for s in fish[1:]):
        found["fish"] = set()  # the adacovex and covex lines disagree
    m = re.search(r"subs=\(([^)]*)\)", text)
    if m is None:
        raise SystemExit("  ERROR: zsh subcommand list not found")
    found["zsh"] = set(m.group(1).split())
    m = re.search(r"\\\$subs = @\(([^)]*)\)", text)
    if m is not None:
        #  The literal may be wrapped across Ada string pieces; the Ada
        #  quotes and concatenation markers are syntax, not content.
        raw: str = m.group(1).replace('"', "").replace("&", " ")
        found["pwsh"] = {tok.strip().strip("'")
                         for tok in re.split(r"[\s,]+", raw) if tok.strip()}
    return found


def agents_blurb() -> str:
    """The `**adacovex**` project paragraph in AGENTS.md."""
    text: str = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
    m = re.search(r"^\*\*adacovex\*\*.*?(?=\n[ \t]*\n)", text,
                  re.M | re.S)
    if m is None:
        raise SystemExit("  ERROR: AGENTS.md has no **adacovex** blurb")
    return m.group(0)


def _check_surface(name: str, text: str, subs: Set[str], flags: Set[str],
                   errors: List[str]) -> None:
    """A reference surface: exact subcommand coverage, real flags only."""
    shown: Set[str] = _advertised_subcommands(text)
    for missing in sorted(subs - shown):
        errors.append(
            f"{name} does not advertise the `{missing}` subcommand; every "
            f"reference surface must list all of them.")
    for extra in sorted(shown - subs):
        errors.append(
            f"{name} advertises `{extra}`, which the parser does not accept "
            f"(stale command example).")
    for flag in sorted(_shown_flags(text) - flags):
        errors.append(
            f"{name} shows `--{flag}`, which is not in Known_Flags "
            f"(stale flag example).")


def _check_tagline(name: str, text: str, tagline: str,
                   errors: List[str]) -> None:
    if tagline not in _normalize(text):
        errors.append(
            f"{name} does not carry the README tagline; copy the README "
            f"description sentence verbatim (wrapping is ignored).")


def check() -> int:
    errors: List[str] = []
    subs: Set[str] = subcommands()
    flags: Set[str] = cli_flags()
    tagline: str = readme_tagline()

    # Reference surfaces: exact subcommand set, no stale examples.
    _check_surface("the `--help` usage block", _usage_block(_config_text()),
                   subs, flags, errors)
    _check_surface("the man page SYNOPSIS", man_synopsis(), subs, flags,
                   errors)
    _check_surface("the cli-reference usage fence", cli_reference_fence(),
                   subs, flags, errors)

    # The tldr page is a cheat-sheet subset: stale examples fail, omissions
    # do not (the reference surfaces above carry the full set).
    page: str = tldr_page()
    for command in tldr_examples(page):
        tokens: List[str] = command.split()
        if not tokens or tokens[0] not in ("adacovex", "covex"):
            errors.append(f"the tldr page runs `{command}`, not adacovex "
                          f"(stale command example).")
            continue
        for index, token in enumerate(tokens[1:], start=1):
            if token.startswith("--"):
                name: str = token[2:].split("=", 1)[0]
                if name not in flags:
                    errors.append(
                        f"the tldr page shows `--{name}`, which is not in "
                        f"Known_Flags (stale flag example).")
            elif token.startswith("-"):
                continue  # shorthands are validated by the CLI e2e checks
            elif index == 1 and token not in subs:
                errors.append(
                    f"the tldr page shows the `{token}` subcommand, which "
                    f"the parser does not accept (stale command example).")

    # Completion scripts: every shell offers the whole subcommand set.
    for shell, shell_subs in sorted(completion_subsets().items()):
        for missing in sorted(subs - shell_subs):
            errors.append(
                f"the {shell} completion script omits the `{missing}` "
                f"subcommand.")
        for extra in sorted(shell_subs - subs):
            errors.append(
                f"the {shell} completion script offers `{extra}`, which the "
                f"parser does not accept (stale subcommand).")

    # One-sentence description: the README tagline on every prose surface.
    _check_tagline("the tldr description", tldr_description(page), tagline,
                   errors)
    _check_tagline("the `--help` output", _help_text(), tagline, errors)
    _check_tagline("the man page DESCRIPTION", man_description(), tagline,
                   errors)
    _check_tagline("the AGENTS.md blurb", agents_blurb(), tagline, errors)

    if errors:
        for e in errors:
            print(f"  ERROR: {e}")
        print(f"  CLI surface parity check FAILED ({len(errors)} error(s))")
        return 1
    print(f"  subcommands: {len(subs)} | flags: {len(flags)} | "
          f"tagline surfaces: 4 | completion shells: "
          f"{len(completion_subsets())}")
    print("  CLI surface parity check passed.")
    return 0


def main(argv: List[str]) -> int:
    ap: argparse.ArgumentParser = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--sources",
        action="store_true",
        help="print the parsed subcommand / flag / tagline sets",
    )
    args: argparse.Namespace = ap.parse_args(argv)
    if args.sources:
        print(f"Subcommands: {sorted(subcommands())}")
        print(f"Flags: {sorted(cli_flags())}")
        print(f"Tagline: {readme_tagline()}")
        print(f"Completion: "
              f"{ {k: sorted(v) for k, v in completion_subsets().items()} }")
        return 0
    return check()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
