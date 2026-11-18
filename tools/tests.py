#!/usr/bin/env python3
"""Unit tests for the tools/*.py dev scripts.

Runs under the stdlib `unittest` only (no third-party packages), matching
the tools' zero-dependency rule:

  python3 tools/tests.py
  python3 -m unittest discover -s tools -p tests.py   (same thing)

The test domains live in sibling modules: `test_release`, `test_docs_generation`,
`test_docs_gates`, `test_tasks`, and `test_misc`.  `testsupport` owns the
shared imports and filesystem helpers.

Exit code 0 when every test passes.
"""

import unittest

from test_release import (ReleaseTagTests, RequirementsSyncTests,
                          SyncToolCheckModeTests, TestRelease,
                          TestVersionConsistency, TestVersions)
from test_docs_generation import (TestGenDashboard, TestGenDocsAssets,
                                  TestGenDocsBuildHelpers,
                                  TestGenDocsBundling, TestGenDocsCodec,
                                  TestGenDocsEncodeCache,
                                  TestGenDocsIncrementalBuild,
                                  TestGenDocsSearchIndex, TestGenTldr,
                                  TestRst2Md)
from test_docs_gates import (CssSpacingTests, DocsTreeTests, ParaSplitTests,
                             TerminologyTests, TestCheckBookLinks,
                             TestCheckDocs, TestCheckDocsCoverage,
                             TestCheckSurfaceParity)
from test_tasks import (BenchCloneTests, CheckGateOrderTests,
                        CheckParallelPhaseTests, CheckReuseTests,
                        CliShardTests, DiagnosticCoverageTests,
                        LiveFilePruneTests, ProofStatusSyncTests,
                        TaskkitLayoutTests, TestCoverageGate,
                        TestLayoutTests)
from test_misc import (SparkOffCheckTests, TestAsciiCheck, TestDevCmd,
                       TestGNATprovePin, TestRun)


if __name__ == "__main__":
    unittest.main(verbosity=2)
