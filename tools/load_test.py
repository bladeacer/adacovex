#!/usr/bin/env python3
"""Concurrent load generator for the --serve dashboard (pure stdlib).

Opens N parallel keep-alive connections and streams sequential HTTP/1.1
GET requests over each, so the server's worker pool (4 tasks by default)
is the concurrency bottleneck under test -- not per-request connection
set-up.  Prints per-run throughput and latency percentiles.

Usage: python3 tools/load_test.py [URL] [CLIENTS] [DURATION_S]
"""

import asyncio
import socket
import statistics
import sys
import time
from typing import List


def parse_args() -> tuple:
    """Return (host, port, path, clients, duration) from argv."""
    url = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8080/api/metrics"
    clients = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    duration = float(sys.argv[3]) if len(sys.argv) > 3 else 5.0
    rest = url.split("://", 1)[1]
    host, _, port_path = rest.partition(":")
    port_s, _, path = port_path.partition("/")
    return host, int(port_s or 80), "/" + path, clients, duration


async def client_worker(
    host: str, port: int, path: str, stop: float, latencies: List[float]
) -> int:
    """Stream keep-alive GETs until the deadline; return request count."""
    count = 0
    reader, writer = await asyncio.open_connection(host, port)
    sock = writer.get_extra_info("socket")
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    req = f"GET {path} HTTP/1.1\r\nHost: {host}\r\n\r\n".encode()
    try:
        while time.monotonic() < stop:
            t0 = time.perf_counter()
            writer.write(req)
            await writer.drain()
            status = await reader.readuntil(b"\r\n\r\n")
            clen = 0
            for line in status.split(b"\r\n"):
                if line.lower().startswith(b"content-length:"):
                    clen = int(line.split(b":")[1])
            if clen:
                await reader.readexactly(clen)
            latencies.append(time.perf_counter() - t0)
            count += 1
    except (asyncio.IncompleteReadError, ConnectionResetError, BrokenPipeError):
        pass
    finally:
        writer.close()
    return count


async def run(host: str, port: int, path: str, clients: int, duration: float) -> None:
    """Run one scenario and print throughput + latency percentiles."""
    latencies: List[float] = []
    stop = time.monotonic() + duration
    tasks = [
        asyncio.create_task(client_worker(host, port, path, stop, latencies))
        for _ in range(clients)
    ]
    counts = await asyncio.gather(*tasks)
    total = sum(counts)
    wall = duration
    lat_sorted = sorted(latencies)
    n = len(lat_sorted)
    p50 = lat_sorted[int(n * 0.50)] if n else float("nan")
    p99 = lat_sorted[min(int(n * 0.99), n - 1)] if n else float("nan")
    pmax = lat_sorted[-1] if n else float("nan")
    print(
        f"clients={clients:>2}  reqs={total:>6}  rps={total / wall:8.0f}  "
        f"p50={p50 * 1000:6.2f}ms  p99={p99 * 1000:6.2f}ms  max={pmax * 1000:7.2f}ms"
    )


def main() -> int:
    """Run all concurrency levels and print the summary table."""
    host, port, path, clients, duration = parse_args()
    print(f"target={host}:{port}{path}  duration={duration}s per level")
    for c in clients if isinstance(clients, list) else [clients]:
        asyncio.run(run(host, port, path, c, duration))
        time.sleep(0.3)
    return 0


if __name__ == "__main__":
    sys.exit(main())
