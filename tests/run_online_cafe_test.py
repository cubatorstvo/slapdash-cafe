"""Three processes: host, teaching guest, then spectator joining a live lesson."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
repo = Path(__file__).resolve().parents[1]
godot = str(Path(sys.argv[1]).resolve()) if len(sys.argv) > 1 else "godot"
with tempfile.TemporaryDirectory(prefix="slapdash-online-") as temp:
    processes, logs = [], []
    def launch(role):
        log = open(Path(temp) / f"{role}.log", "w+")
        logs.append((role, log))
        env = dict(os.environ, XDG_DATA_HOME=str(Path(temp) / role))
        processes.append(subprocess.Popen([godot, "--headless", "--path", str(repo), "--script", "tests/test_online_cafe.gd", "--", role], stdout=log, stderr=subprocess.STDOUT, env=env))
    try:
        launch("host")
        time.sleep(1)
        launch("guest")
        deadline = time.monotonic() + 24
        while time.monotonic() < deadline:
            if "READY: late join" in (Path(temp) / "host.log").read_text():
                launch("observer")
                break
            if any(p.poll() is not None for p in processes):
                break
            time.sleep(0.1)
        codes = [p.wait(timeout=35) for p in processes]
        failed = any(codes) or len(processes) != 3
        for role, log in logs:
            log.seek(0)
            output = log.read()
            print(f"{role}:\n{output[-7000:]}")
            failed |= "SCRIPT ERROR" in output or "FAIL:" in output or "PASS:" not in output
            for line in output.splitlines():
                if line.startswith("ERROR:") and "resources still in use" not in line:
                    failed = True
        sys.exit(1 if failed else 0)
    finally:
        for p in processes:
            if p.poll() is None:
                p.terminate()
                p.wait(timeout=5)
        for _, log in logs: log.close()
