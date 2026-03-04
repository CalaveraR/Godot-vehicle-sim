#!/usr/bin/env python3
"""Run deterministic parity/consistency checks defined in manifest.

Designed to scale to additional domains (suspension, tires, wheels, engine)
without changing CI wiring.
"""

import json
import subprocess
import sys
from pathlib import Path


def main() -> int:
    manifest_path = Path("tools/parity/manifest.json")
    manifest = json.loads(manifest_path.read_text())
    failures = []

    for check in manifest.get("checks", []):
        name = check["name"]
        cmd = check["command"]
        print(f"[parity] RUN {name}: {cmd}")
        result = subprocess.run(cmd, shell=True)
        if result.returncode != 0:
            failures.append((name, result.returncode))

    if failures:
        print("\n[parity] FAILED")
        for name, code in failures:
            print(f" - {name} (exit={code})")
        return 1

    print("\n[parity] OK all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
