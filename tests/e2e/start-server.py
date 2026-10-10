#!/usr/bin/env python3
"""Start the adacovex dashboard server for e2e tests."""
import subprocess
import sys
import os

def main():
    repo_root = os.path.dirname(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    )
    adacovex = os.path.join(repo_root, 'bin', 'adacovex')
    
    # Build if needed
    if not os.path.exists(adacovex):
        print("Building adacovex...", file=sys.stderr)
        subprocess.run(['make', 'build'], cwd=repo_root, check=True)
    
    # Start server
    cmd = [adacovex, '--serve', '--port=8080']
    print(f"Starting: {' '.join(cmd)}", file=sys.stderr)
    proc = subprocess.Popen(cmd, cwd=repo_root)
    try:
        proc.wait()
    except KeyboardInterrupt:
        proc.terminate()
        proc.wait()
    return proc.returncode

if __name__ == '__main__':
    sys.exit(main())
