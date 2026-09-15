# Server throughput and latency

`--serve` runs a small HTTP/1.1 server with a worker pool. This page
records its per-request cost and its throughput under concurrent
keep-alive load. The machine and the harness are on
[Benchmarking adacovex](benchmarks.md).

## The serve dashboard API

The `--serve` endpoints were benchmarked with hyperfine over curl on the
same machine (local loopback, 4-worker server, one curl process per
request):

| Endpoint | Mean | Notes |
|----------|------|-------|
| `GET /api/metrics` | ~6-7 ms | JSON, ~0.5 KB response |
| `GET /` | ~10-13 ms | HTML, ~245 KB response |
| `GET /docs/` | ~5 ms | gzip manual page, ~6 KB response |

The numbers are dominated by curl's own process startup and connection
cycle (its strace shows ~390 syscalls per invocation, nearly all dynamic
loader `mmap`/`openat` work), so keep-alive client libraries see far lower
per-request costs. The server-side share is small: the JSON endpoints
serialise in-process data (microseconds of CPU), and the dashboard page is
rebuilt per request from the immutable assessment state. 1.47.0 removed
the largest server-side syscall cost: the request reader used to pull one
byte per `Receive_Socket` call, ~300 receive syscalls per request; it now
fills a 4 KiB per-connection buffer per receive and hands out complete
CRLF lines from it.

## Concurrent load (keep-alive clients, 20 s runs)

`tools/load_test.py` (pure-stdlib asyncio) streams sequential keep-alive
GETs from N parallel client connections, so the 4-worker pool is the
capacity being measured:

| Scenario | Throughput | Latency p50 / p99 |
|----------|-----------|-------------------|
| `/api/metrics`, 1 client | ~45k req/s | 0.02 / 0.07 ms |
| `/api/metrics`, 4 clients | ~94k req/s | 0.04 / 0.14 ms |
| `/api/metrics`, 16 clients | ~84k req/s | 0.04 / 0.15 ms |
| `/badge/spark.svg`, 8 clients | ~97k req/s | 0.03 / 0.13 ms |
| `/`, 4 clients | ~530 req/s | 6.3 / 13.6 ms |
| `/docs/`, 4 clients | ~97 req/s | 41 / 43 ms |

JSON and badge endpoints scale near-linearly to the worker count (4
requests in flight = 4 workers saturated) and hold ~84-97k req/s with 16
clients, because extra clients queue in the accept backlog instead of
consuming server resources. Tail latency stays sub-millisecond; the ~4 s
max above the worker count is a load-generator deadline artifact (one
straggler request per connection at the cutoff), not server behaviour.
`perf stat` under load shows no cache-miss or IPC anomaly; `strace -c`
splits the request cost evenly between `recvfrom` and `sendto` at ~16 us
each, with `futex` (worker parking) leading wall clock only because the
load is light for four workers. The dashboard page (~245 KB rendered per
request) and the manual index are throughput-bound on response assembly
and socket copies; both hold flat latency under load. Capacity is far
above single-operator needs; `--serve-workers=N` raises the pool.

## See also

- [Benchmarking adacovex](benchmarks.md) -- the machine and the harness.
- [Performance](index.md) -- the benchmark category definitions.
- [Pipeline and prove timings](benchmarks-timings.md) -- the timing table.
