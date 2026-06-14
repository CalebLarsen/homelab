#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

def main():
    files = sys.argv[1:]
    if not files:
        sys.exit(0)

    try:
        subprocess.run(["sops", "--version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("ERROR: 'sops' is not installed or not in PATH.", file=sys.stderr)
        sys.exit(1)

    fail = False
    for f in files:
        path = Path(f)
        if not path.is_file():
            continue

        if path.name in [".sops.yaml", ".sops.yml"]:
            continue

        try:
            result = subprocess.run(["sops", "filestatus", str(path)], capture_output=True, text=True, check=True)
            status = json.loads(result.stdout)
            if not status.get("encrypted"):
                print(f"ERROR: {f} is NOT encrypted according to SOPS.", file=sys.stderr)
                print(f"  If you intentionally want plaintext, rename the file to drop .sops.", file=sys.stderr)
                print(f"  To encrypt: sops -e -i {f}", file=sys.stderr)
                fail = True
        except subprocess.CalledProcessError as e:
            print(f"ERROR: Failed to check sops status for {f}: {e.stderr}", file=sys.stderr)
            fail = True
        except json.JSONDecodeError:
            print(f"ERROR: Failed to parse sops output for {f}", file=sys.stderr)
            fail = True

    if fail:
        sys.exit(1)

if __name__ == "__main__":
    main()
