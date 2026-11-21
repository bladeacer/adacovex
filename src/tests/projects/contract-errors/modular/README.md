# Contract error: modular

One contract-writing mistake with its fixed counterpart. The broken
variant is expected to report the range check on a modular narrowing; the fixed variant proves.

The pair is driven by `src/tests/e2e/prove/prove_diagnostics.py` and
named in the diagnostics matrix in
`docs/contributing/proving-diagnostics.md`.
