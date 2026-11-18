# Consumer action fixture

A tiny zero-dependency Alire crate with no `adacovex.gpr`. The composite
action detects this shape as a consumer workspace, builds the target's native
tests itself, and runs `test-command`.

`alr build` produces `./fixture_main` (`Exec_Dir "."`), which prints
`fixture tests passed`. The `consumer-run-tests` CI job copies this tree into
the workspace root and runs `uses: ./` against it.
