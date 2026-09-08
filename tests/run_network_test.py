"""Run two real ENet peers with isolated saves: python tests/run_network_test.py /path/to/godot"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
repo = Path(__file__).resolve().parents[1]
godot = str(Path(sys.argv[1]).resolve()) if len(sys.argv) > 1 else "godot"
with tempfile.TemporaryDirectory(prefix="slapdash-net-") as temp:
    processes, logs = [], []
    try:
        for role in ("host", "guest"):
            log = open(Path(temp) / f"{role}.log", "w+")
            logs.append(log)
            env = dict(os.environ, XDG_DATA_HOME=str(Path(temp) / role))
            processes.append(subprocess.Popen([godot, "--headless", "--path", str(repo), "--script", "tests/test_network_peer.gd", "--", role], stdout=log, stderr=subprocess.STDOUT, env=env))
            if role == "host": time.sleep(1)
        codes = [p.wait(timeout=25) for p in processes]
        failed = any(codes)
        for role, log in zip(("host", "guest"), logs):
            log.seek(0)
            output = log.read()
            print(f"{role}:\n{output[-6000:]}")
            failed |= "SCRIPT ERROR" in output or "ERROR:" in output or "PASS:" not in output
        sys.exit(1 if failed else 0)
    finally:
        for p in processes:
            if p.poll() is None:
                p.terminate()
                p.wait(timeout=5)
        for log in logs: log.close()
