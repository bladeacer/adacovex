# Action project-config fixture

A SPARK crate whose `adacovex.toml` must change the prove run exactly as the
binary's own precedence rule says: the project file wins over the global file
and the built-in default.

`[prove] level = 1` and `coverage = false` are asserted from the teed proof
log by the `action-project-config` CI job after `uses: ./` runs.
