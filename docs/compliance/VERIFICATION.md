# adacovex Verification Report

## Source Overview

| Metric | Value |
|--------|-------|
| Packages Scanned |  46 |
| Total Subprograms |  278 |
| Documented Subprograms |  278 |
| Docstring Coverage |  100% |

## SPARK Proof Analysis

| Check Type | Count | Proved |
|------------|-------|--------|
| SPARK Level | Gold | - |
| Flow (data + flow dependencies) |  76 |  76 |
| Initialization |  17 |  17 |
| Runtime Checks |  602 |  602 |
| Assertions |  133 |  133 |
| Functional Contracts |  98 |  98 |
| Termination |  132 |  132 |
| **Total** |  1058 |  1058 |
| Units Analyzed |  76 | - |
| Units Skipped |  0 | - |

## Test Results

| Category | Tests | Status |
|----------|-------|--------|
| Types conversions |  72 | PASS |
| DAL compliance |  23 | PASS |
| Source scanner |  89 | PASS |
| GNATprove parser |  88 | PASS |
| Test-result parser |  50 | PASS |
| CLI config |  387 | PASS |
| SVG renderer |  161 | PASS |
| HTML/Markdown renderers |  58 | PASS |
| SBOM generator |  580 | PASS |
| Result cache |  36 | PASS |
| IR synthesis |  42 | PASS |
| Man page renderer |  30 | PASS |
| VCS support |  37 | PASS |
| Server routing |  183 | PASS |
| Proof patches |  35 | PASS |
| Timezone + ANSI |  73 | PASS |
| Complexity check |  20 | PASS |
| Opt-out markers |  20 | PASS |
| Dir cache |  29 | PASS |
| Diff reports |  36 | PASS |
| Prove runner |  104 | PASS |
| SPARK coverage |  18 | PASS |
| ANSI terminal report |  28 | PASS |
| CPU and jobs |  24 | PASS |
| HLR/LLR parsing |  33 | PASS |
| Completion scripts |  24 | PASS |
| Platform paths |  43 | PASS |
| Install method |  23 | PASS |
| tldr installer |  48 | PASS |
| **Total** | ** 2394** | **Passed:  2394, Failed:  0** |

## DO-178C Compliance

| Criterion | Status |
|-----------|--------|
| Target level | DAL-C |
| Overall Status | Achieved |
| HLR Traced |  61 /  61 |
| Orphan Tags | No |
| Tests Passing | Yes |
| Min SPARK Level | Yes |
