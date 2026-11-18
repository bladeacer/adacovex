"""Dashboard serve shorthand, health, watch, theme, and port checks."""

from cli_support import *  # noqa: F401,F403


def check_serve_shorthands(r: Results, tmp: Path) -> None:
    body, _ = serve_get_retry(
        lambda port: ["serve", "-t", str(tmp), "-p", str(port),
                      "--workers=2", "--no-sbom", "--no-svg", "--no-md",
                      "--no-cache"],
        "/api/metrics",
    )
    payload: Optional[dict] = None
    if body is not None:
        try:
            payload = json.loads(body)
        except ValueError:
            payload = None
    r.check(
        payload is not None
        and "spark_level" in payload
        and "standard" in payload,
        "serve -s/-p/--workers starts the dashboard and answers /api/metrics",
    )

def check_serve_info_health(r: Results, tmp: Path) -> None:
    """The /health probe and the /api/info payload of a live server."""
    base = ["serve", "-t", str(tmp), "--workers=2",
            "--no-sbom", "--no-svg", "--no-md", "--no-cache"]

    health, _ = serve_get_retry(
        lambda port: base + ["-p", str(port)], "/health")
    r.check(
        health is not None and health.strip() == '{"status": "ok"}',
        "serve answers /health with the JSON health verdict",
    )

    info, info_port = serve_get_retry(
        lambda port: base + ["-p", str(port)], "/api/info")
    payload: Optional[dict] = None
    if info is not None:
        try:
            payload = json.loads(info)
        except ValueError:
            payload = None
    r.check(
        payload is not None
        and payload.get("version")
        and payload.get("target") == str(tmp)
        and payload.get("standard") == "all"
        and payload.get("port") == info_port
        and payload.get("workers") == 2
        and isinstance(payload.get("uptime_seconds"), int)
        and isinstance(payload.get("assessment_ms"), int)
        and isinstance(payload.get("cache"), dict)
        and isinstance(payload.get("requests"), dict),
        "serve answers /api/info with the run metadata and counters",
    )

    routes = []
    if payload is not None:
        routes = [e.get("path")
                  for e in payload.get("requests", {}).get("routes", [])]
    r.check(
        "/health" in routes and "/api/info" in routes
        and "/api/metrics" in routes and "*" in routes,
        "the info payload counts every route bucket",
    )

def check_serve_watch(r: Results, tmp: Path) -> None:
    """Serve watches document metrics by default; --no-watch turns it off."""
    proj = tmp / "watch-proj"
    write_project(proj, 1)
    base = ["serve", "-t", str(proj), "--workers=2",
            "--no-sbom", "--no-svg", "--no-md", "--no-cache"]

    def get(port: int, path: str) -> Optional[str]:
        try:
            with urllib.request.urlopen(
                    f"http://127.0.0.1:{port}{path}", timeout=2) as resp:
                return resp.read().decode("utf-8", "replace")
        except (urllib.error.URLError, OSError, ValueError):
            return None

    port = free_port()
    proc = subprocess.Popen(
        [BIN] + base + ["-p", str(port)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        cwd=str(ROOT),
    )
    try:
        first: Optional[int] = None
        for _ in range(60):
            body = get(port, "/api/watch")
            if body:
                try:
                    payload = json.loads(body)
                except ValueError:
                    payload = {}
                if payload.get("watching") is True and payload.get(
                        "generation", 0) >= 1:
                    first = int(payload["generation"])
                    break
            time.sleep(0.5)
        r.check(first is not None,
                "serve watches by default and publishes a generation")

        (proj / "src" / "p01.ads").write_text(
            "package P01 is\n   --  Run the P01 step.\n   procedure Go;\n"
            "end P01;\n",
            encoding="utf-8",
        )
        moved: Optional[int] = None
        for _ in range(60):
            body = get(port, "/api/watch")
            if body:
                try:
                    data = json.loads(body)
                except ValueError:
                    data = {}
                if (first is not None
                        and int(data.get("generation", 0)) > first):
                    moved = int(data["generation"])
                    break
            time.sleep(0.5)
        r.check(moved is not None,
                "an edit advances the watch generation")
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=10)

    off, _ = serve_get_retry(
        lambda port: base + ["-p", str(port), "--no-watch"], "/api/watch")
    off_payload: Optional[dict] = None
    if off is not None:
        try:
            off_payload = json.loads(off)
        except ValueError:
            off_payload = None
    r.check(
        off_payload is not None and off_payload.get("watching") is False,
        "--no-watch serves the starting metrics without polling",
    )

    bad = run(["--no-watch"])
    r.check(
        bad.returncode == 1
        and "requires the serve subcommand" in bad.stderr,
        "rejects --no-watch outside the serve subcommand",
    )

def check_theme_and_port(r: Results, tmp: Path) -> None:
    # An unknown theme and a missing theme value fail loudly at parse time.
    bad = run(["--theme=neon"])
    r.check(
        bad.returncode == 1
        and "--theme must be light, dark, or system" in bad.stderr,
        "rejects an unknown --theme value",
    )
    missing = run(["--theme"])
    r.check(
        missing.returncode == 1
        and "--theme requires a value" in missing.stderr,
        "rejects --theme without a value",
    )

    # The CLI theme reaches the served dashboard, and the port shorthand
    # works in both the "=" and the glued form.
    for theme, form in (("dark", "-p=PORT"), ("light", "-pPORT")):
        def args_for(port: int) -> List[str]:
            port_arg = f"-p={port}" if form == "-p=PORT" else f"-p{port}"
            return ["serve", "-t", str(tmp), port_arg, f"--theme={theme}",
                    "--workers=2", "--no-sbom", "--no-svg", "--no-md",
                    "--no-cache"]

        body, _ = serve_get_retry(args_for, "/")
        r.check(
            body is not None
            and f'data-initial-theme="{theme}"' in body,
            f"serve applies --theme={theme} with the {form} port shorthand",
        )
