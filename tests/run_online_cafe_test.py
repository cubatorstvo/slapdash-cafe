"""Three processes: host, teaching guest, then spectator joining a live lesson."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
repo = Path(__file__).resolve().parents[1]
godot = str(Path(sys.argv[1]).resolve()) if len(sys.argv) > 1 else "godot"
keep_logs = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else Path(os.environ["SLAPDASH_ONLINE_LOGDIR"]).resolve() if os.environ.get("SLAPDASH_ONLINE_LOGDIR") else None
with tempfile.TemporaryDirectory(prefix="slapdash-online-") as temp:
    log_root = keep_logs if keep_logs is not None else Path(temp)
    log_root.mkdir(parents=True, exist_ok=True)
    processes, logs = [], []
    def launch(role):
        path = log_root / f"{role}.log"
        log = open(path, "w+")
        logs.append((role, log, path))
        env = dict(os.environ, XDG_DATA_HOME=str(Path(temp) / role))
        processes.append(subprocess.Popen([godot, "--headless", "--path", str(repo), "--script", "tests/test_online_cafe.gd", "--", role], stdout=log, stderr=subprocess.STDOUT, env=env))
    try:
        launch("host")
        time.sleep(1)
        launch("guest")
        deadline = time.monotonic() + 24
        while time.monotonic() < deadline:
            if "READY: late join" in (log_root / "host.log").read_text():
                launch("observer")
                break
            if any(p.poll() is not None for p in processes):
                break
            time.sleep(0.1)
        codes = [p.wait(timeout=35) for p in processes]
        failed = any(codes) or len(processes) != 3
        summary = []
        for (role, log, path), code in zip(logs, codes if len(codes) == len(logs) else list(codes) + [None] * len(logs)):
            log.seek(0)
            output = log.read()
            print(f"{role} exit={code}:\n{output[-7000:]}")
            summary.append(f"{role}={code}")
            failed |= "SCRIPT ERROR" in output or "ERROR:" in output or "FAIL:" in output or "PASS:" not in output
        print("CODES: " + " ".join(summary) + (" logdir=" + str(log_root) if keep_logs else ""))
        sys.exit(1 if failed else 0)
    finally:
        for p in processes:
            if p.poll() is None:
                p.terminate()
                p.wait(timeout=5)
        for _, log, _ in logs: log.close()
