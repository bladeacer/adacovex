# Syscall profile

`strace -c` counts the syscalls of one warm pipeline run. strace serialises the workload, so the table is for counts, never for wall time. The profile follows child processes (`strace -f`); this run spawned none (`execve` is 1), so every call belongs to adacovex. A host without strace writes no table and says so.

<!-- perf-report:begin -->
Measured on adacovex `1.75.0` on 2026-11-24.

| Syscall | Calls |
|---------|-------|
| `newfstatat` | 282020 |
| `openat` | 11474 |
| `read` | 8084 |
| `write` | 318 |
| `execve` | 1 |
| `total` | 346737 |
<!-- perf-report:end -->

The `newfstatat` count is the directory-walk cost. The directory-snapshot memo took a warm tree to 7 924 calls at 1.63.0, so the figure here is a regression rather than the memo's floor, and [technical debt register](../contributing/debt.md) entry D16 owns it. The cache design is on [Global configuration and state](../usage/configuration.md).
