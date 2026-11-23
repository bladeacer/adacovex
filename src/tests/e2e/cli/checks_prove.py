"""Differential, prove, and tldr-install checks."""

from cli_support import *  # noqa: F401,F403


def check_differential(r: Results, tmp: Path) -> None:
    repo = tmp / "diff-repo"
    write_project(repo, 1)
    if not git_init_commit(repo):
        r.skip("differential assessment",
               "git is not available (the checks need a VCS)")
        return

    suppress = ["--no-sbom", "--no-svg", "--no-md", "--no-cache"]
    long_form = run(["--target", str(repo), "--compare-base=HEAD", *suppress])
    r.check(
        "Differential assessment: base <HEAD> vs current" in long_form.stdout
        and "DAL status" in long_form.stdout,
        "--compare-base=HEAD prints the differential report",
    )

    # Every alias spelling must leave the same parsed state as the canonical
    # long flag, so the reports are byte-identical.
    for label, args in (
        ("--diff", ["--diff=HEAD"]),
        ("--base", ["--base=HEAD"]),
        ("-b=", ["-b=HEAD"]),
        ("-b REF", ["-b", "HEAD"]),
    ):
        proc = run(["-t", str(repo), *args, *suppress])
        r.check(
            proc.stdout == long_form.stdout
            and proc.returncode == long_form.returncode,
            f"{label}=REF equals --compare-base=REF",
        )

    long_delta = run(["-t", str(repo), "--coverage-delta=HEAD"])
    r.check(
        long_delta.returncode == 0
        and "Coverage delta: base <HEAD> vs current" in long_delta.stdout
        and "coverage_delta:" in long_delta.stdout,
        "--coverage-delta=HEAD prints the coverage table and delta line",
    )
    for label, args in (
        ("--delta", ["--delta=HEAD"]),
        ("-d=", ["-d=HEAD"]),
        ("-d REF", ["-d", "HEAD"]),
    ):
        proc = run(["-t", str(repo), *args])
        r.check(
            proc.stdout == long_delta.stdout
            and proc.returncode == long_delta.returncode,
            f"{label}=REF equals --coverage-delta=REF",
        )

    # A target outside any repository must fail loudly, not silently.
    plain = tmp / "diff-novcs"
    plain.mkdir(parents=True, exist_ok=True)
    no_vcs = run(["-t", str(plain), "-b", "HEAD", *suppress])
    r.check(
        no_vcs.returncode == 1
        and "--compare-base requires" in no_vcs.stderr
        and "repository" in no_vcs.stderr,
        "-b REF fails loudly on a target that is not a repository",
    )

def check_differential_regression(r: Results, tmp: Path) -> None:
    repo = tmp / "diff-regression"
    write_documented_project(repo, 1)
    if not git_init_commit(repo):
        r.skip("coverage-delta regression",
               "git is not available (the checks need a VCS)")
        return

    clean = run(["-t", str(repo), "--coverage-delta=HEAD"])
    r.check(
        clean.returncode == 0 and "regressed=no" in clean.stdout,
        "--coverage-delta reports no regression on an unchanged tree",
    )

    # Add an undocumented subprogram: docstring coverage drops 100% -> 50%.
    src = repo / "src"
    (src / "p01.ads").write_text(
        "package P01 is\n"
        "   --  Run the P01 step.\n"
        "   procedure Go;\n"
        "   procedure Extra;\n"
        "end P01;\n",
        encoding="utf-8",
    )
    (src / "p01.adb").write_text(
        "package body P01 is\n"
        "   --  Run the P01 step.\n"
        "   procedure Go is\n   begin\n      null;\n   end Go;\n"
        "   procedure Extra is\n   begin\n      null;\n   end Extra;\n"
        "end P01;\n",
        encoding="utf-8",
    )

    delta = run(["-t", str(repo), "--coverage-delta=HEAD"])
    r.check(
        delta.returncode == 1
        and "COVERAGE REGRESSION" in delta.stdout
        and "regressed=yes" in delta.stdout,
        "--coverage-delta flags a docstring-coverage drop and exits 1",
    )

    compare = run(["-t", str(repo), "--compare-base=HEAD",
                   "--no-sbom", "--no-svg", "--no-md", "--no-cache"])
    r.check(
        compare.returncode == 1
        and "REGRESSION DETECTED" in compare.stdout,
        "--compare-base reports REGRESSION DETECTED for a coverage drop",
    )

def check_prove(r: Results, tmp: Path) -> None:
    # A target with no .gpr file makes prove fail after argument parsing and
    # before gnatprove runs.  The prover is resolved before the project file
    # is looked for, so the resolved prover is put on $PATH (when the host
    # has one) to reach that error deterministically; a host with no prover
    # stops at the resolver instead.  Either stop is after the parser, which
    # is what the check measures, so both count.
    nope = tmp / "prove-target"
    nope.mkdir(parents=True, exist_ok=True)
    no_gpr = "no root .gpr project file found"
    no_prover = "could not download the gnatprove toolchain"
    env = prover_env()

    accepted = run(["prove", "-t", str(nope), "-l", "2", "-j", "2",
                    "--timeout=60", "--steps=1000", "--memlimit=100",
                    "--quiet", "--no-loop-unrolling", "--no-inlining",
                    "--counterexamples=off"],
                   env_extra=env)
    r.check(
        accepted.returncode == 1
        and (no_gpr in accepted.stderr or no_prover in accepted.stderr),
        "prove parses -t/-l/-j and the full prove option set",
    )

    short = run(["prove", "-t", str(nope), "-l=2", "-j=2"], env_extra=env)
    long_form = run(["prove", "--target", str(nope), "--level=2", "--jobs=2"],
                    env_extra=env)
    r.check(
        short.returncode == long_form.returncode
        and short.stderr == long_form.stderr,
        "prove -t/-l/-j shorthands equal their long forms",
    )

    rejects: Tuple[Tuple[List[str], str, str], ...] = (
        (["--level=bogus"], "--level must be an integer",
         "a non-numeric --level"),
        (["-l", "99"], "--level must be in", "an out-of-range --level"),
        (["--jobs=99999"], "--jobs must be in", "an out-of-range --jobs"),
        (["--timeout=-1"], "--timeout must be in",
         "an out-of-range --timeout"),
        (["--memlimit=0"], "--memlimit must be in",
         "an out-of-range --memlimit"),
        (["--fail-on=bogus=1"], "--fail-on must name",
         "an unknown --fail-on dimension"),
        (["--fail-on=proof=101"], "--fail-on=proof must be in",
         "an out-of-range --fail-on=proof"),
        (["--fail-on=spark"], "--fail-on=spark needs a level",
         "a bare --fail-on=spark with no --require-spark"),
        (["--counterexamples=maybe"], "--counterexamples must be on or off",
         "an unknown --counterexamples value"),
    )
    for args, needle, label in rejects:
        proc = run(["prove", "-t", str(nope), *args])
        r.check(
            proc.returncode == 1 and needle in proc.stderr,
            f"prove rejects {label} with '{needle}'",
        )

    for args, label in (
        (["-j", "2"], "the -j shorthand"),
        (["--force"], "--force"),
        (["--steps=100"], "--steps"),
        (["-l", "1"], "the -l shorthand"),
        (["--coverage"], "the --coverage flag"),
        (["--no-coverage"], "the --no-coverage flag"),
        (["--counterexamples=off"], "the --counterexamples flag"),
    ):
        proc = run(args)
        r.check(
            proc.returncode == 1
            and "require the prove subcommand" in proc.stderr,
            f"rejects {label} outside the prove subcommand",
        )

def check_tldr_install(r: Results, tmp: Path) -> None:
    """Install the bundled tldr page into a fake client and read it back.

    The fake `tldr` on PATH answers `--show-paths` (tealdeer) or only
    `--version` (a base client), so the check exercises client detection,
    the page path per family, the byte-exact install, and --check without a
    real client, a network, or the user's own page tree.
    """
    if os.name == "nt":
        r.skip("tldr install", "the fake client is a POSIX shell stub")
        return
    home = tmp / "tldr-home"
    bin_dir = tmp / "tldr-bin"
    home.mkdir()
    bin_dir.mkdir()
    stub = bin_dir / "tldr"
    stub.write_text(
        "#!/bin/sh\n"
        'if [ "$1" = "--show-paths" ]; then\n'
        '  echo "Custom pages dir: $HOME/.local/share/tealdeer/pages/' \
        ' (OS convention)"\n'
        "  exit 0\n"
        "fi\n"
        'echo "tealdeer 1.9.0"\n',
        encoding="utf-8",
    )
    stub.chmod(0o755)
    env: Dict[str, str] = {
        "HOME": str(home),
        "XDG_DATA_HOME": "",
        "XDG_CACHE_HOME": "",
        "PATH": str(bin_dir),
    }
    page = (ROOT / "docs" / "tldr" / "adacovex.md").read_bytes()
    tealdeer_page = home / ".local/share/tealdeer/pages/adacovex.page.md"

    proc = run(["tldr", "--check"], env_extra=env)
    r.check(
        proc.returncode == 1 and "out of date" in proc.stdout,
        "tldr --check reports a missing page",
    )
    proc = run(["tldr"], env_extra=env)
    r.check(
        proc.returncode == 0 and "tldr page installed" in proc.stdout,
        "tldr installs the page into the tealdeer custom pages dir",
    )
    r.check(
        tealdeer_page.is_file() and tealdeer_page.read_bytes() == page,
        "the installed tealdeer page is byte-identical to the bundled page",
    )
    proc = run(["tldr", "--check"], env_extra=env)
    r.check(
        proc.returncode == 0 and "up to date" in proc.stdout,
        "tldr --check passes after the install",
    )
    tealdeer_page.write_text("stale\n", encoding="utf-8")
    proc = run(["tldr", "--check"], env_extra=env)
    r.check(
        proc.returncode == 1 and "out of date" in proc.stdout,
        "tldr --check detects a stale page",
    )

    #  A base client does not answer --show-paths and prints a plain tldr
    #  version, so the page lands in its cache pages tree.
    stub.write_text(
        "#!/bin/sh\n"
        'if [ "$1" = "--show-paths" ]; then exit 2; fi\n'
        'echo "tldr 3.3.9"\n',
        encoding="utf-8",
    )
    proc = run(["tldr"], env_extra=env)
    #  A base client writes into the host cache root: ~/Library/Caches on
    #  macOS, the XDG cache (~/.cache) elsewhere.  An XDG cache override is
    #  cleared above, so the platform rule decides the path.
    if sys.platform == "darwin":
        common_page = home / "Library/Caches/tldr/pages/common/adacovex.md"
    else:
        common_page = home / ".cache/tldr/pages/common/adacovex.md"
    r.check(
        proc.returncode == 0 and "base client" in proc.stdout,
        "tldr detects a base client from its version output",
    )
    r.check(
        common_page.is_file() and common_page.read_bytes() == page,
        "a base client gets the byte-identical common page",
    )
