#!/usr/bin/env python3
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TESTS = sorted(p for p in (ROOT / "tests").glob("test_*.gd") if p.name != "test_online_cafe.gd")


def find_godot(explicit: str | None) -> str:
    candidates = [explicit, os.environ.get("GODOT_BIN"), shutil.which("godot4"), shutil.which("godot")]
    for candidate in candidates:
        if candidate:
            return str(candidate)
    raise SystemExit("Godot not found. Pass --godot /path/to/godot or set GODOT_BIN.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run every single-process Slapdash Cafe GDScript regression in an isolated user data directory.")
    parser.add_argument("--godot", help="Path to the Godot 4.7 executable")
    parser.add_argument("--timeout", type=int, default=180, help="Per-test timeout in seconds")
    args = parser.parse_args()
    godot = find_godot(args.godot)
    failed: list[str] = []

    print(f"Godot: {godot}")
    print(f"Tests: {len(TESTS)}")
    for index, test in enumerate(TESTS, 1):
        with tempfile.TemporaryDirectory(prefix="slapdash-test-") as user_data:
            env = os.environ.copy()
            env["XDG_DATA_HOME"] = user_data
            env["GODOT_SILENCE_ROOT_WARNING"] = "1"
            command = [godot, "--headless", "--path", str(ROOT), "--script", f"res://tests/{test.name}"]
            try:
                result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=args.timeout)
            except subprocess.TimeoutExpired as exc:
                failed.append(test.name)
                print(f"[{index:02d}/{len(TESTS):02d}] FAIL {test.name} (timeout)")
                if exc.stdout:
                    print(exc.stdout[-4000:])
                if exc.stderr:
                    print(exc.stderr[-4000:])
                continue
        if result.returncode == 0:
            print(f"[{index:02d}/{len(TESTS):02d}] PASS {test.name}")
        else:
            failed.append(test.name)
            print(f"[{index:02d}/{len(TESTS):02d}] FAIL {test.name} (exit {result.returncode})")
            combined = (result.stdout or "") + (result.stderr or "")
            print(combined[-6000:])

    if failed:
        print(f"FAILED {len(failed)}/{len(TESTS)}: {', '.join(failed)}")
        return 1
    print(f"PASS {len(TESTS)}/{len(TESTS)} single-process tests")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
