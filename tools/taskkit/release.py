"""Version bump, release, publish, and the all-target sync."""

import os
import subprocess

from .common import PY, ROOT, py, run
from .gates import (task_agents_tree, task_description, task_docs_tree,
                    task_proof_status, task_requirements, task_test_count)


def task_bump_version() -> int:
    return py("tools/bump-version.py", os.environ.get("VERSION", ""))

def task_release() -> int:
    args = ["tools/release.py", f"--version={os.environ.get('VERSION', '')}"]
    if os.environ.get("DRY_RUN"):
        args.append("--dry-run")
    return py(*args)

def task_publish() -> int:
    status = subprocess.run(
        ["git", "status", "--porcelain"], cwd=str(ROOT),
        capture_output=True, text=True,
    ).stdout.strip()
    if status:
        print("Error: working tree is not clean. Commit or stash changes first.")
        return 1
    return run(["alr", "publish"])

def task_test_publish() -> int:
    version = subprocess.run(
        ["git", "describe", "--tags", "--abbrev=0"], cwd=str(ROOT),
        capture_output=True, text=True,
    ).stdout.strip()
    if not version:
        version = subprocess.run(
            [PY, "tools/versions.py", "current"], cwd=str(ROOT),
            capture_output=True, text=True,
        ).stdout.strip()
    print("=== test-publish dry-run ===")
    print(f"Version:  {version}")
    print("Action:   alr publish (auto-detects GitHub, test deps excluded)")
    print("Requires: GitHub PAT in GITHUB_TOKEN env var or gh auth token")
    print("Docs:     "
          "https://github.com/alire-project/alire/blob/master/doc/publishing.md")
    print("=== end dry-run ===")
    return 0

def task_sync() -> int:
    for action in (task_agents_tree, task_proof_status, task_test_count,
                   task_docs_tree, task_description, task_requirements):
        rc = action()
        if rc != 0:
            return rc
    print("All sync targets up to date.")
    return 0
