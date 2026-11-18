# End-to-end suites

Every end-to-end suite lives under this root, in a category directory:

- `cli/` -- `cli_flags.py`, the real binary's flags, aliases, and exit codes.
- `prove/` -- `prove_diagnostics.py`, the diagnostics block over the
  `src/tests/projects/contract-errors/` fixture pairs.
- `dashboard/` -- the Playwright layout suite, its config, and the server
  helper (the only suite that needs a browser, and it runs on Linux).
- `action/` -- the assertion the CI action job runs against its proof log.
- `lib/` -- shared Python: the repository root, the binary, the result
  recorder with its skip rule, the environment, and a free port.

No suite writes an Ada project inline. A fixture is a real project tree under
`src/tests/projects/`, which `just test-layout-check` enforces.
