# Syscall profile

`strace -c` counts the syscalls of one warm pipeline run. strace serialises the workload, so the table is for counts, never for wall time. The profile follows child processes (`strace -f`); this run spawned none (`execve` is 1), so every call belongs to adacovex. A host without strace writes no table and says so.

<!-- perf-report:begin -->
Measured on adacovex `1.75.0` on 2026-11-25.

| Syscall | Calls |
|---------|-------|
| `newfstatat` | 18904 |
| `read` | 4551 |
| `openat` | 1243 |
| `write` | 318 |
| `execve` | 1 |
| `total` | 29326 |
<!-- perf-report:end -->

The `newfstatat` count is the directory-walk cost. The figure fell from 282 020 to 18 904 when the debt D16 fix made every walker share one directory snapshot, so the count is now the tree's own size rather than a repeat of it. The cache design is on [Global configuration and state](../usage/configuration.md), and the fix is on [the debt register](../contributing/debt.md).
