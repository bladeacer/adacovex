"""Complexity, init, configuration, SPARK coverage, and timezone checks."""

from cli_support import *  # noqa: F401,F403


def check_cache(r: Results, tmp: Path) -> None:
    """The cache flags: resolved keys, lifetime, and clear.

    Two runs of the same project use one cache from different working
    directories. The relative and the absolute spelling must resolve to one
    key, so the second run reports no miss. --cache-expiry configures the
    lifetime, and --cache-clear removes every entry and exits 0.
    """
    proj = tmp / "cache-proj"
    write_project(proj, 2)
    cache = tmp / "cache-store"
    common = ["--no-svg", "--no-md", "--no-sbom", "--cache-dir", str(cache)]

    first = run(["-t", "cache-proj"] + common, cwd=tmp)
    second = run(["-t", str(proj)] + common, cwd=tmp)
    r.check("result cache:" in first.stdout, "cache: the first run completes")
    r.check(
        "result cache:" in second.stdout and "0 miss(es)" in second.stdout,
        "cache: a relative and an absolute target share one entry set",
    )
    r.check(
        "0 evicted" in second.stdout,
        "cache: the warm run evicts nothing",
    )

    verbose = run(
        ["-t", str(proj)] + common + ["--cache-expiry=0", "--verbose"])
    r.check(
        "expiry=0 day(s)" in verbose.stderr,
        "cache: --cache-expiry=0 configures the lifetime",
    )

    #  A per-file key: editing one unit in a 32-package project keeps the
    #  other records and misses only the changed file.
    big = tmp / "cache-big"
    write_documented_project(big, 32)
    run(["-t", str(big)] + common)
    run(["-t", str(big)] + common)
    unit = big / "src" / "p01.ads"
    unit.write_text(
        unit.read_text(encoding="utf-8") + "--  edited\n", encoding="utf-8")
    edited = run(["-t", str(big)] + common)
    match = re.search(
        r"result cache:\s+(\d+) hit\(s\), (\d+) miss\(es\)", edited.stdout)
    r.check(match is not None, "cache: the edited run reports its outcomes")
    if match is not None:
        hits, misses = int(match.group(1)), int(match.group(2))
        r.check(
            hits >= 31 and misses <= 1,
            f"cache: one edited unit misses alone (hits={hits},"
            f" misses={misses})",
        )

    #  SBOM caching follows the same resolved target: the graph entry from
    #  one working directory serves a run from another, and both runs emit
    #  the same document.
    sbom_proj = tmp / "cache-sbom"
    write_fixture(sbom_proj, {
        "alire.toml": 'name = "cachesbom"\nversion = "1.0.0"\n',
        "demo.gpr": (
            'project Demo is\n'
            '   for Source_Dirs use ("src");\n'
            '   for Object_Dir use "obj";\n'
            'end Demo;\n'),
        "src/p.ads": "package P is\n   procedure Go;\nend P;\n",
        "src/p.adb": (
            "package body P is\n   procedure Go is\n   begin\n"
            "      null;\n   end Go;\nend P;\n"),
    })
    sbom_cache = tmp / "cache-sbom-store"
    sbom_args = [
        "sbom", "--format=cyclonedx-json",
        "--out", str(tmp / "cache-sbom.json"),
        "--cache-dir", str(sbom_cache), "--no-svg", "--no-md",
    ]
    parent_run = run(
        [*sbom_args, "--target=cache-sbom"], cwd=tmp)
    entries_before = {
        p.relative_to(sbom_cache) for p in sbom_cache.rglob("*") if p.is_file()
    }
    project_run = run(
        [*sbom_args, "--target", str(sbom_proj)], cwd=sbom_proj)
    entries_after = {
        p.relative_to(sbom_cache) for p in sbom_cache.rglob("*") if p.is_file()
    }
    r.check(
        parent_run.returncode == 0 and project_run.returncode == 0,
        "cache: sbom runs from the parent and the project directories",
    )
    r.check(
        entries_after == entries_before,
        "cache: an sbom from another cwd adds no cache entry",
    )
    r.check(
        parent_run.stdout.split("SBOM written to", 1)[-1]
        == project_run.stdout.split("SBOM written to", 1)[-1],
        "cache: an sbom from another cwd reports the same result",
    )

    refused = run(["--cache-clear", "--cache-dir", "/"])
    r.check(
        refused.returncode == 1 and "refused to clear" in refused.stderr,
        "cache: --cache-clear refuses a file-system root",
    )

    cleared = run(["--cache-clear", "--cache-dir", str(cache)])
    r.check(
        cleared.returncode == 0 and "cache cleared:" in cleared.stdout,
        "cache: --cache-clear prints the count and exits 0",
    )
    r.check(
        not cache.exists()
        or not any(p.is_file() for p in cache.rglob("*")),
        "cache: --cache-clear removed every entry",
    )

def check_complexity(r: Results, tmp: Path) -> None:
    # A single-package project fails the gate (each file dominates the
    # codebase); a 20-package project passes (each file is ~5%).
    small = tmp / "cx-small"
    write_project(small, 1)
    (small / "notes.md").write_text("# notes\n", encoding="utf-8")
    big = tmp / "cx-big"
    write_project(big, 20)

    passing = run(["complexity", "--target", str(big)])
    r.check(
        passing.returncode == 0
        and "Complexity/LOC gate passed." in passing.stdout,
        "complexity passes a well-sized project and exits 0",
    )
    r.check(
        "Language" in passing.stdout and "files analyzed:" in passing.stdout,
        "complexity prints the tokei summary and the per-file table",
    )

    shorthand = run(["complexity", "-t", str(big)])
    r.check(
        shorthand.returncode == 0 and shorthand.stdout == passing.stdout,
        "complexity -t resolves the same target as --target",
    )

    failing = run(["complexity", "-t", str(small)])
    r.check(
        failing.returncode == 1
        and "Complexity/LOC gate FAILED" in failing.stdout,
        "complexity exits 1 and reports the gate failure",
    )

    included = run(["complexity", "-t", str(small)])
    excluded = run(["complexity", "-t", str(small), "--excludes=md"])
    r.check(
        "notes.md" in included.stdout and "notes.md" not in excluded.stdout,
        "complexity --excludes=md drops the Markdown file",
    )

    skipped = run(["complexity", "-t", str(small), "--skip-path=src"])
    r.check(
        "src/p01.adb" in included.stdout
        and "src/p01.adb" not in skipped.stdout
        and "src/p01.ads" not in skipped.stdout,
        "complexity --skip-path=src drops the files under src/",
    )

    # A directory that carries .covex-ignore is excluded with its subtree,
    # and the marker file itself never counts as source.
    vendored = big / "src" / "vendored"
    vendored.mkdir(parents=True, exist_ok=True)
    (vendored / ".covex-ignore").write_text("", encoding="utf-8")
    (vendored / "huge.adb").write_text(
        "--  vendored line\n" * 5000, encoding="utf-8")
    ignored = run(["complexity", "-t", str(big)])
    r.check(
        "huge.adb" not in ignored.stdout
        and ".covex-ignore" not in ignored.stdout
        and ignored.returncode == 0,
        "complexity skips a directory carrying .covex-ignore",
    )

def check_init(r: Results, tmp: Path) -> None:
    """Scaffold a project file and honour the global [init] scaffold switch."""
    state = tmp / "init-state"
    env = {"ADACOVEX_STATE_HOME": str(state)}
    proj = tmp / "init-proj"
    proj.mkdir()
    created = run(["init", "-t", str(proj)], env_extra=env)
    cfg = proj / "adacovex.toml"
    text = cfg.read_text(encoding="utf-8") if cfg.is_file() else ""
    r.check(
        created.returncode == 0
        and cfg.is_file()
        and "[prove]" in text
        and "[complexity]" in text
        and "readthedocs.io/en/latest/usage/configuration.html" in text,
        "init writes a scaffolded adacovex.toml that links to the manual",
    )
    kept = run(["init", "-t", str(proj)], env_extra=env)
    r.check(
        kept.returncode == 1
        and "already exists" in kept.stdout
        and cfg.read_text(encoding="utf-8") == text,
        "init leaves an existing project file alone and exits 1",
    )
    forced = run(["init", "-t", str(proj), "--force"], env_extra=env)
    r.check(forced.returncode == 0, "init --force rewrites the project file")

    state.mkdir(parents=True, exist_ok=True)
    (state / "adacovex.toml").write_text(
        "[init]\nscaffold = false\n", encoding="utf-8")
    off = tmp / "init-off"
    off.mkdir()
    disabled = run(["init", "-t", str(off)], env_extra=env)
    r.check(
        disabled.returncode == 0
        and not (off / "adacovex.toml").exists()
        and "scaffold" in disabled.stdout,
        "global [init] scaffold = false disables project scaffolding",
    )

def check_config_files(r: Results, tmp: Path) -> None:
    """Precedence across the project and global adacovex.toml files.

    The complexity gate is the observable: `[complexity] excludes = "md"`
    drops the Markdown file from the report without needing a prover.
    """
    proj = tmp / "cfg-proj"
    write_project(proj, 20)
    (proj / "notes.md").write_text("# notes\n", encoding="utf-8")
    project_cfg = proj / "adacovex.toml"

    def state(name: str, text: Optional[str] = None) -> Dict[str, str]:
        root = tmp / f"cfg-state-{name}"
        root.mkdir()
        if text is not None:
            (root / "adacovex.toml").write_text(text, encoding="utf-8")
        return {"ADACOVEX_STATE_HOME": str(root)}

    baseline = run(["complexity", "-t", str(proj)], env_extra=state("base"))
    r.check(
        baseline.returncode == 0 and "notes.md" in baseline.stdout,
        "complexity scans the Markdown file without a configuration file",
    )

    project_cfg.write_text('[complexity]\nexcludes = "md"\n', encoding="utf-8")
    project = run(["complexity", "-t", str(proj)], env_extra=state("project"))
    r.check(
        project.returncode == 0 and "notes.md" not in project.stdout,
        "a project file's [complexity] excludes changes a real run",
    )

    project_cfg.unlink()
    global_only = run(
        ["complexity", "-t", str(proj)],
        env_extra=state("global", '[complexity]\nexcludes = "md"\n'))
    r.check(
        global_only.returncode == 0 and "notes.md" not in global_only.stdout,
        "a global file's [complexity] excludes changes the same run",
    )

    docs = proj / "docs"
    docs.mkdir()
    (docs / "other.py").write_text("x = 1\n", encoding="utf-8")
    project_cfg.write_text(
        '[complexity]\nexcludes = "rst"\n', encoding="utf-8")
    both = run(
        ["complexity", "-t", str(proj)],
        env_extra=state(
            "both",
            '[complexity]\nexcludes = "md"\nskip-path = "docs"\n'))
    r.check(
        both.returncode == 0
        and "notes.md" in both.stdout
        and "other.py" not in both.stdout,
        "the project file wins per key while the global file supplies the rest",
    )

    project_cfg.write_text(
        '[complexity]\nexcludes = "md"\n', encoding="utf-8")
    flagged = run(
        ["complexity", "-t", str(proj), "--excludes=rst"],
        env_extra=state("flag", '[complexity]\nexcludes = "md"\n'))
    r.check(
        flagged.returncode == 0 and "notes.md" in flagged.stdout,
        "an explicit --excludes wins over both configuration files",
    )

    other_cwd = tmp / "cfg-cwd"
    other_cwd.mkdir()
    (other_cwd / "adacovex.toml").write_text(
        '[complexity]\nexcludes = "rst"\n', encoding="utf-8")
    project_cfg.write_text('[complexity]\nexcludes = "md"\n', encoding="utf-8")
    elsewhere = run(
        ["complexity", "-t", str(proj)],
        env_extra=state("target"), cwd=other_cwd)
    r.check(
        elsewhere.returncode == 0 and "notes.md" not in elsewhere.stdout,
        "--target reads the target's file only, never the working directory's",
    )

    project_cfg.write_text(
        "[unknown]\nvalue = true\njobs = 1\nlevel = 0\n", encoding="utf-8")
    empty_cfg = run(
        ["complexity", "-t", str(proj)], env_extra=state("empty"))
    project_cfg.write_text(
        "[prove]\ncoverage = false\njobs = 1\nlevel = 0\n", encoding="utf-8")
    prove_untouched = run(
        ["complexity", "-t", str(proj)], env_extra=state("prove"))
    r.check(
        empty_cfg.returncode == 0
        and prove_untouched.returncode == 0
        and prove_untouched.stdout == empty_cfg.stdout,
        "[prove] keys change nothing outside the prove subcommand",
    )

    long_path = "x" * 5000
    malformed = (
        "",
        "# only a comment\n",
        "[unknown]\nkey = 1\n",
        "[prove]\njobs = not-an-integer\n",
        '[prove]\nlevel = "unterminated\n',
        f'[complexity]\nskip-path = "{long_path}"\n',
    )
    big = tmp / "cfg-big"
    write_project(big, 20)
    malformed_ok = True
    for index, content in enumerate(malformed):
        project_cfg.write_text(content, encoding="utf-8")
        proc = run(["complexity", "-t", str(big)],
                   env_extra=state(f"bad{index}"))
        if proc.returncode != 0:
            malformed_ok = False
    project_cfg.unlink()
    r.check(malformed_ok,
            "a malformed or unknown configuration never fails a run")

    project_cfg.write_text("# no keys\n", encoding="utf-8")
    baseline_big = run(["complexity", "-t", str(big)],
                       env_extra=state("bigbase"))
    project_cfg.write_text(
        (ROOT / "adacovex.toml").read_text(encoding="utf-8"),
        encoding="utf-8")
    with_sample = run(["complexity", "-t", str(big)],
                      env_extra=state("sample"))
    r.check(
        with_sample.returncode == 0
        and with_sample.stdout == baseline_big.stdout,
        "the shipped sample adacovex.toml leaves a real run unchanged",
    )

def check_config_prove(r: Results, tmp: Path) -> None:
    """The [prove] keys and flags need a real prover; skip without one.

    The skip asks `resolved_prover` -- the same resolution order the binary
    uses -- not `$PATH` alone, so a host whose prover lives in the toolchain
    cache runs the group instead of skipping it.  The group redirects the
    state home to isolate the result cache, which also hides the cache the
    prover came from, so the resolved executable's directory is put on
    $PATH for the child runs.
    """
    if resolved_prover() is None:
        r.skip("prove-side configuration",
               "no gnatprove on PATH or in the toolkit cache"
               " (the checks need a prover)")
        return
    proj = tmp / "cfg-prove"
    write_provable_project(proj, 2)
    state = tmp / "cfg-prove-state"
    state.mkdir()
    env = {"ADACOVEX_STATE_HOME": str(state), **prover_env()}
    base = ["prove", "-t", str(proj), "--no-cache", "-j", "1", "-l", "0"]

    #  Coverage is on by default for `adacovex prove`.
    default = run(base, env_extra=env, timeout=900)
    r.check(
        default.returncode == 0 and "coverage:" in default.stdout,
        "`adacovex prove` shows the coverage summary by default",
    )

    #  --no-coverage hides it for one run.
    hidden = run([*base, "--no-coverage"], env_extra=env, timeout=900)
    r.check(
        hidden.returncode == 0 and "coverage:" not in hidden.stdout,
        "`--no-coverage` hides the coverage summary",
    )

    (proj / "adacovex.toml").write_text(
        "[prove]\ncoverage = false\n", encoding="utf-8")
    configured = run(base, env_extra=env, timeout=600)
    r.check(
        configured.returncode == 0 and "coverage:" not in configured.stdout,
        "project [prove] coverage = false hides the coverage summary",
    )
    shown = run([*base, "--coverage"], env_extra=env, timeout=600)
    r.check(
        shown.returncode == 0 and "coverage:" in shown.stdout,
        "an explicit --coverage wins over the project file",
    )
    #  The composite action runs `prove` with its inputs as flags. A target
    #  repository's project file must reach that invocation too.
    action_like = run(
        ["prove", "-t", str(proj), "--jobs=1", "--level=0"],
        env_extra=env, timeout=900)
    r.check(
        action_like.returncode == 0
        and "coverage:" not in action_like.stdout,
        "the composite action's prove invocation honours a project file",
    )

    #  Plain `adacovex` (no prove subcommand) also shows coverage when proof
    #  artefacts are available in the target (left by the run above).  The
    #  project file is removed first: it sets `coverage = false`, and that
    #  key would suppress the line for the right reason but prove nothing
    #  about the assessment path.
    (proj / "adacovex.toml").unlink()
    plain = run(["-t", str(proj)], env_extra=env, timeout=600)
    r.check(
        plain.returncode == 0 and "coverage:" in plain.stdout,
        "plain `adacovex` shows coverage from cached proof artefacts",
    )
    global_cfg = state / "adacovex.toml"
    global_cfg.write_text("[prove]\ncoverage = false\n", encoding="utf-8")
    global_run = run(base, env_extra=env, timeout=600)
    r.check(
        global_run.returncode == 0 and "coverage:" not in global_run.stdout,
        "a global [prove] key changes the same run",
    )
    global_cfg.unlink()

    common = ["prove", "-t", str(proj), "-j", "1"]
    (proj / "adacovex.toml").write_text(
        "[prove]\ncoverage = false\nlevel = 0\n", encoding="utf-8")
    cold = run(common, env_extra=env, timeout=900)
    warm = run(common, env_extra=env, timeout=900)
    r.check(
        cold.returncode == 0
        and warm.returncode == 0
        and "reusing prior proof" in warm.stdout,
        "a repeated prove reuses the cached proof",
    )
    (proj / "adacovex.toml").write_text(
        "[prove]\ncoverage = false\nlevel = 1\n", encoding="utf-8")
    changed = run(common, env_extra=env, timeout=900)
    r.check(
        changed.returncode == 0 and "reusing prior proof" not in changed.stdout,
        "a config-supplied level changes the proof cache identity",
    )

def write_spark_fixture(path: Path) -> None:
    """Scaffold a project with the two proof artefacts the report reads.

    The report never runs the prover: it reads obj/gnatprove/gnatprove.out
    and its SARIF sibling.  Writing both keeps the check independent of any
    real proof run, so it behaves the same on a developer tree and on a
    fresh CI checkout.
    """
    src = path / "src"
    proof = path / "obj" / "gnatprove"
    src.mkdir(parents=True, exist_ok=True)
    proof.mkdir(parents=True, exist_ok=True)
    (src / "foo.adb").write_text(
        "package body Foo is\n"
        "\n"
        "   procedure Do_It is\n"
        "   begin\n"
        "      null;\n"
        "   end Do_It;\n"
        "\n"
        "   procedure Helped is\n"
        "   begin\n"
        "      null;\n"
        "   end Helped;\n"
        "\n"
        "end Foo;\n",
        encoding="utf-8",
    )
    (proof / "gnatprove.out").write_text(
        "GNATprove 16.1.0\n"
        "in unit foo, 1 subprograms and packages out of 2 analyzed\n"
        "  Foo.Helped at foo.adb:9 skipped; body is SPARK_Mode => Off\n",
        encoding="utf-8",
    )
    (proof / "gnatprove.sarif").write_text(
        '{"version":"2.1.0","runs":[{"results":['
        '{"ruleId":"vc1","kind":"pass","level":"none",'
        '"locations":[{"physicalLocation":{"artifactLocation":'
        '{"uri":"foo.adb"},"region":{"startLine":5}}}],'
        '"logicalLocations":[{"name":"Foo.Do_It"}]},'
        '{"ruleId":"warn1","kind":"pass","level":"warning",'
        '"locations":[{"physicalLocation":{"artifactLocation":'
        '{"uri":"foo.adb"},"region":{"startLine":5}}}],'
        '"logicalLocations":[{"name":"Foo.Do_It"}]}]}]}',
        encoding="utf-8",
    )

def check_spark_coverage(r: Results, tmp: Path) -> None:
    """The report reads a committed artefact pair, never the repo's own.

    A project with no artefacts fails loudly.  A project with the pair
    produces every metric, the three off classes, a parseable JSON report,
    and the gate's exit codes.
    """
    empty = tmp / "spark-empty"
    write_project(empty, 1)
    no_artefacts = run(["spark-coverage", "--target", str(empty)])
    r.check(
        no_artefacts.returncode == 1 and "gnatprove" in no_artefacts.stdout,
        "spark-coverage exits 1 when the proof artefacts are missing",
    )

    proj = tmp / "spark-fixture"
    write_spark_fixture(proj)
    report = run(["spark-coverage", "--target", str(proj), "--group=package"])
    r.check(
        report.returncode == 0
        and "Statement coverage" in report.stdout
        and "Subprogram coverage" in report.stdout
        and "VC coverage" in report.stdout,
        "spark-coverage prints all three metrics",
    )
    r.check(
        "irreducible" in report.stdout
        and "io-bound" in report.stdout
        and "work queue" in report.stdout,
        "spark-coverage prints the three off classes",
    )

    json_report = run(
        ["spark-coverage", "--target", str(proj), "--spark-format=json"]
    )
    parsed = None
    try:
        parsed = json.loads(json_report.stdout)
    except ValueError:
        parsed = None
    r.check(
        json_report.returncode == 0
        and isinstance(parsed, dict)
        and "statements" in parsed.get("metrics", {})
        and "off_classes" in parsed,
        "spark-coverage --spark-format=json emits valid JSON",
    )

    gate_ok = run(
        [
            "spark-coverage",
            "--target",
            str(proj),
            "--require-coverage=0",
            "--gate-metric=vcs",
        ]
    )
    r.check(
        gate_ok.returncode == 0,
        "spark-coverage exits 0 when the gate metric meets the threshold",
    )
    gate_fail = run(
        [
            "spark-coverage",
            "--target",
            str(proj),
            "--require-coverage=100",
            "--gate-metric=subprograms",
        ]
    )
    r.check(
        gate_fail.returncode == 1
        and "subprograms" in gate_fail.stdout,
        "spark-coverage exits 1 below the threshold and names the metric",
    )

    #  The spark-coverage flags only work with the subcommand.
    misplaced = run(["--group=folder"])
    r.check(
        misplaced.returncode == 1
        and "spark-coverage subcommand" in misplaced.stderr,
        "--group without spark-coverage is rejected",
    )

def check_timezone(r: Results, tmp: Path) -> None:
    """Timestamps default to UTC+0; --tz=local opts into the local zone.

    `status` exits 1 when the host cannot prove, which is the readiness
    line and not a timezone failure, so the exit code is accepted as either
    documented value and the timestamp text carries the check.
    """
    proj = tmp / "tz-proj"
    write_project(proj, 1)
    default = run(["status", "-t", str(proj)])
    r.check(
        default.returncode in (0, 1) and "UTC+00:00" in default.stdout,
        "default status timestamp is UTC+00:00",
    )
    local = run(
        ["status", "-t", str(proj), "--tz=local"],
        env_extra={"TZ": "Asia/Singapore"},
    )
    r.check(
        local.returncode in (0, 1) and "Asia/Singapore" in local.stdout,
        "--tz=local reports the operator's wall-clock zone (Asia/Singapore)",
    )
    offset = run(["status", "-t", str(proj), "--tz=UTC+8"])
    r.check(
        offset.returncode in (0, 1) and "UTC+08:00" in offset.stdout,
        "--tz=UTC+8 reports the explicit offset (UTC+08:00)",
    )
