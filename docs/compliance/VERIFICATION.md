# adacovex Verification Report

## Source Overview

| Metric | Value |
|--------|-------|
| Packages Scanned |  40 |
| Total Subprograms |  180 |
| Documented Subprograms |  180 |
| Docstring Coverage |  100% |

## SPARK Proof Analysis

| Check Type | Count | Proved |
|------------|-------|--------|
| SPARK Level | Platinum | - |
| Flow (data + flow dependencies) |  62 |  62 |
| Initialization |  11 |  11 |
| Runtime Checks |  481 |  481 |
| Assertions |  123 |  123 |
| Functional Contracts |  97 |  97 |
| Termination |  106 |  106 |
| **Total** |  880 |  880 |
| Units Analyzed |  66 | - |
| Units Skipped |  0 | - |

## Test Results

| Category | Tests | Status |
|----------|-------|--------|
| Types conversions |  67 | PASS |
| DAL compliance |  16 | PASS |
| Source scanner |  89 | PASS |
| GNATprove parser |  64 | PASS |
| Test-result parser |  50 | PASS |
| CLI config |  343 | PASS |
| SVG renderer |  161 | PASS |
| HTML/Markdown renderers |  58 | PASS |
| SBOM generator |  288 | PASS |
| Result cache |  28 | PASS |
| IR synthesis |  42 | PASS |
| Man page renderer |  18 | PASS |
| VCS support |  29 | PASS |
| Server routing |  41 | PASS |
| Proof patches |  35 | PASS |
| Timezone + ANSI |  63 | PASS |
| Complexity check |  12 | PASS |
| Opt-out markers |  16 | PASS |
| Dir cache |  22 | PASS |
| Diff reports |  36 | PASS |
| Prove runner |  20 | PASS |
| ANSI terminal report |  28 | PASS |
| CPU and jobs |  24 | PASS |
| HLR/LLR parsing |  33 | PASS |
| Completion scripts |  24 | PASS |
| **Total** | ** 1607** | **Passed:  1607, Failed:  0** |

## DO-178C Compliance

| Criterion | Status |
|-----------|--------|
| Target level | DAL-C |
| Overall Status | Achieved |
| HLR Traced |  57 /  57 |
| Orphan Tags | No |
| Tests Passing | Yes |
| Min SPARK Level | Yes |
