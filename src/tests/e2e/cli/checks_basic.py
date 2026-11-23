"""Version, help, completion, rejection, and tier-token checks."""

from cli_support import *  # noqa: F401,F403


def check_version(r: Results) -> None:
    proc = run(["--version"])
    r.check(proc.returncode == 0, "--version exits 0")
    r.check(
        re.fullmatch(r"adacovex v\d+\.\d+\.\d+\s*", proc.stdout) is not None,
        "--version prints the bundled version",
    )

def check_help(r: Results) -> None:
    proc = run(["--help"])
    r.check(proc.returncode == 0, "--help exits 0")
    r.check("--target" in proc.stdout, "--help lists --target")
    r.check(run(["help"]).stdout == proc.stdout,
            "--help and help print the same usage")
    for topic, needle in HELP_TOPICS:
        topic_proc = run(["help", topic])
        r.check(
            topic_proc.returncode == 0 and needle in topic_proc.stdout,
            f"help {topic} prints the {needle} section",
        )
    for topic, usage in HELP_FRAMES:
        text = run(["help", topic]).stdout
        r.check(
            text.startswith("adacovex v")
            and "Usage:" in text
            and f"  {usage}" in text
            and "Options:" in text
            and "Run 'adacovex --help' for the full option list." in text,
            f"help {topic} renders the --help frame",
        )
    r.check(run(["help", "serve"]).stdout == run(["--serve", "help"]).stdout,
            "--serve help equals help serve")
    prove_help = run(["prove", "help"]).stdout
    r.check(prove_help == run(["prove", "--help"]).stdout,
            "prove --help equals prove help")
    r.check(all(flag in prove_help
                for flag in ("-j", "-l", "--args", "--suppress-warnings",
                             "--counterexamples")),
            "prove help lists the prove flags")
    near = run(["help", "statu"])
    r.check(
        "unknown help topic 'statu'" in near.stdout
        and "(did you mean --status?)" in near.stdout
        and "Valid topics:" in near.stdout
        and "complexity" in near.stdout,
        "an unknown help topic suggests the nearest topic and lists them",
    )
    far = run(["help", "zzzzzz"])
    r.check(
        "unknown help topic 'zzzzzz'" in far.stdout
        and "Valid topics:" in far.stdout
        and "did you mean" not in far.stdout,
        "a distant help topic gets no suggestion but still lists them",
    )
    typo = run(["--standrd=all"])
    r.check("(did you mean --standard?)" in typo.stderr,
            "the flag suggestion closes its parenthesis")

def check_completion(r: Results) -> None:
    for shell in ("bash", "fish", "zsh", "pwsh"):
        proc = run(["completion", shell])
        missing = [name for name in ALIAS_NAMES if name not in proc.stdout]
        r.check(
            proc.returncode == 0 and not missing,
            f"completion {shell} advertises every alias"
            + (f" (missing: {', '.join(missing)})" if missing else ""),
        )

def check_rejections(r: Results) -> None:
    cases: Tuple[Tuple[List[str], str, str], ...] = (
        (["--nope"], "unknown option", "an unknown option"),
        (["zzz"], "unknown argument", "an unknown bare word"),
        (["--standard=bogus"], "--standard must be",
         "an unknown --standard value"),
        (["-l", "2"], "require the prove subcommand",
         "the -l shorthand without the prove subcommand"),
        (["--workers=6"], "requires the serve subcommand",
         "--workers without --serve"),
    )
    for args, needle, label in cases:
        proc = run(args)
        r.check(
            proc.returncode == 1 and needle in proc.stderr,
            f"rejects {label} with '{needle}'",
        )

def check_tier_tokens(r: Results, tmp: Path) -> None:
    for token, standard, level in TIER_TOKENS:
        out = tmp / f"sbom-{token}.md"
        proc = run(["sbom", "-t", str(tmp), "--format=md",
                    f"--out={out}", f"--standard={token}"])
        text = out.read_text(encoding="utf-8") if out.is_file() else ""
        has_standard = f"| adacovex:standard | {standard} |" in text
        if level is None:
            ok = proc.returncode == 0 and has_standard \
                and "| adacovex:level |" not in text
            label = (f"--standard={token} selects {standard} with no level"
                     " row (no-safety-effect tier)")
        else:
            ok = proc.returncode == 0 and has_standard \
                and f"| adacovex:level | {level} |" in text
            label = f"--standard={token} selects {standard} at {level}"
        r.check(ok, label)
