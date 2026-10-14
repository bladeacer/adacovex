# adacovex Verification Report

## Source Overview

| Metric | Value |
|--------|-------|
| Packages Scanned |  43 |
| Total Subprograms |  219 |
| Documented Subprograms |  219 |
| Docstring Coverage |  100% |

## SPARK Proof Analysis

| Check Type | Count | Proved |
|------------|-------|--------|
| SPARK Level | Platinum | - |
| Flow (data + flow dependencies) |  73 |  73 |
| Initialization |  17 |  17 |
| Runtime Checks |  599 |  599 |
| Assertions |  133 |  133 |
| Functional Contracts |  97 |  97 |
| Termination |  127 |  127 |
| **Total** |  1046 |  1046 |
| Units Analyzed |  72 | - |
| Units Skipped |  0 | - |

## Test Results

| Category | Tests | Status |
|----------|-------|--------|
| Types conversions |  67 | PASS |
| DAL compliance |  23 | PASS |
| Source scanner |  89 | PASS |
| GNATprove parser |  72 | PASS |
| Test-result parser |  50 | PASS |
| CLI config |  349 | PASS |
| SVG renderer |  161 | PASS |
| HTML/Markdown renderers |  58 | PASS |
| SBOM generator |  366 | PASS |
| Result cache |  36 | PASS |
| IR synthesis |  42 | PASS |
| Man page renderer |  18 | PASS |
| VCS support |  29 | PASS |
| Server routing |  133 | PASS |
| Proof patches |  35 | PASS |
| Timezone + ANSI |  63 | PASS |
| Complexity check |  20 | PASS |
| Opt-out markers |  16 | PASS |
| Dir cache |  22 | PASS |
| Diff reports |  36 | PASS |
| Prove runner |  24 | PASS |
| SPARK coverage |  18 | PASS |
| ANSI terminal report |  28 | PASS |
| CPU and jobs |  24 | PASS |
| HLR/LLR parsing |  33 | PASS |
| Completion scripts |  24 | PASS |
| Platform paths |  43 | PASS |
| Install method |  23 | PASS |
| **Total** | ** 1902** | **Passed:  1902, Failed:  0** |

## DO-178C Compliance

| Criterion | Status |
|-----------|--------|
| Target level | DAL-C |
| Overall Status | Achieved |
| HLR Traced |  59 /  59 |
| Orphan Tags | No |
| Tests Passing | Yes |
| Min SPARK Level | Yes |
