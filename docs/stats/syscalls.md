# Syscall profile

`strace -c` counts the syscalls of one warm pipeline run. strace serialises the workload, so the table is for counts, never for wall time. The profile follows child processes (`strace -f`), so it also counts the package-manager probes the SBOM resolution runs. A host without strace writes no table and says so.

<!-- perf-report:begin -->
Measured on adacovex `1.75.0` on 2026-11-24.

| Syscall | Calls |
|---------|-------|
| `newfstatat` | 281996 |
| `openat` | 11474 |
| `read` | 8096 |
| `execve` | 1 |
| `write` | 318 |
| `total` | 346724 |
<!-- perf-report:end -->

The `newfstatat` count is the directory-walk cost, and the directory-snapshot memo is what keeps it down on a warm tree. The cache design is on [Global configuration and state](../usage/configuration.md).
