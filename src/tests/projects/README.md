# Test fixture projects

One directory per fixture project. Each fixture is a real, standalone Alire
crate: its own `alire.toml`, its own GNAT project file, its own `src/`, and a
README that names the check it exercises.

The root `adacovex.gpr` never lists these directories, so `alr build` and the
root test runner never compile them. The strict docstring scan still reads a
fixture spec, so a fixture subprogram carries a docstring exactly as a shipped
one does.

- `consumer-action/` -- the zero-dependency crate the composite action builds
  and runs in a consumer workspace (no `adacovex.gpr`).
- `action-project-config/` -- the crate whose `adacovex.toml` must change the
  action's prove run (proof level 1, coverage off).
- `contract-errors/<class>/{broken,fixed}/` -- a SPARK contract-writing
  mistake and its fixed counterpart. `case.toml` states the check the
  diagnostics block must name.

CI copies a fixture tree into a workspace; it never writes a project inline in
a workflow. `just test-layout-check` enforces that rule.
