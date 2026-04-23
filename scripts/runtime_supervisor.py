#!/usr/bin/env python3
from __future__ import annotations

import atexit
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

REPO_ROOT = Path(__file__).resolve().parents[1]
LOG_DIR = Path.home() / 'Library' / 'Logs' / 'Cartly'
LOG_PATH = LOG_DIR / 'runtime-supervisor.log'
PID_FILE = LOG_DIR / 'runtime-supervisor.pid'
SAFE_PATH = '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'
INTERVAL_SECONDS = float(os.environ.get('CARTLY_RUNTIME_SUPERVISOR_INTERVAL_SECONDS', '5') or '5')
ENSURE_NAS = REPO_ROOT / 'scripts' / 'ensure-nas-mount.sh'
BACKEND_ONCE = REPO_ROOT / 'scripts' / 'run-backend-once-login-session.sh'
WORKER_ONCE = REPO_ROOT / 'scripts' / 'run-worker-login-session.sh'

stop_requested = False
log_stream = None
backend_proc: Optional[subprocess.Popen] = None
worker_proc: Optional[subprocess.Popen] = None


def log(message: str) -> None:
    print(message, flush=True)


def setup_logging() -> None:
    global log_stream
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_stream = open(LOG_PATH, 'a', buffering=1)
    os.dup2(log_stream.fileno(), sys.stdout.fileno())
    os.dup2(log_stream.fileno(), sys.stderr.fileno())


def cleanup_pid_file() -> None:
    try:
        if PID_FILE.exists() and PID_FILE.read_text().strip() == str(os.getpid()):
            PID_FILE.unlink()
    except Exception:
        pass


def on_exit() -> None:
    cleanup_pid_file()
    log(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] runtime supervisor exit")
    if log_stream is not None:
        log_stream.flush()


def handle_signal(signum, _frame) -> None:
    global stop_requested
    stop_requested = True
    log(f"[supervisor] shutdown requested signal={signum}")


def ensure_singleton() -> None:
    if PID_FILE.exists():
        existing = PID_FILE.read_text().strip()
        if existing:
            try:
                os.kill(int(existing), 0)
            except OSError:
                pass
            else:
                log(f"[supervisor] already running with pid={existing}")
                raise SystemExit(0)
    PID_FILE.write_text(str(os.getpid()))


def port_listening(port: int) -> bool:
    result = subprocess.run(
        ['/usr/sbin/lsof', f'-iTCP:{port}', '-sTCP:LISTEN'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def has_live_process(pattern: str) -> bool:
    result = subprocess.run(
        ['/usr/bin/pgrep', '-f', pattern],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return False

    for raw_pid in result.stdout.splitlines():
        pid = raw_pid.strip()
        if not pid:
            continue
        state = subprocess.run(
            ['/bin/ps', '-o', 'state=', '-p', pid],
            capture_output=True,
            text=True,
            check=False,
        ).stdout.strip()
        if state and not state.startswith('Z'):
            return True
    return False


def ensure_nas_ready() -> bool:
    result = subprocess.run(
        [str(ENSURE_NAS)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        cwd=str(REPO_ROOT),
        check=False,
        env={**os.environ, 'PATH': SAFE_PATH},
    )
    return result.returncode == 0


def launch(script: Path) -> subprocess.Popen:
    return subprocess.Popen(
        [str(script)],
        cwd=str(REPO_ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env={**os.environ, 'PATH': SAFE_PATH},
    )


def reap(label: str, proc: Optional[subprocess.Popen]) -> Optional[subprocess.Popen]:
    if proc is None:
        return None
    code = proc.poll()
    if code is None:
        return proc
    log(f"[supervisor] {label} launcher exited code={code}")
    return None


def ensure_backend() -> None:
    global backend_proc
    if port_listening(8011) or has_live_process('run-backend-once-login-session.sh'):
        return
    if not ensure_nas_ready():
        log('[supervisor] backend restart skipped because NAS mount is unavailable')
        return
    log('[supervisor] backend missing, starting launcher')
    backend_proc = launch(BACKEND_ONCE)


def ensure_worker() -> None:
    global worker_proc
    if has_live_process('backend/worker_daemon.py') or has_live_process('run-worker-login-session.sh'):
        return
    if not ensure_nas_ready():
        log('[supervisor] worker restart skipped because NAS mount is unavailable')
        return
    log('[supervisor] worker missing, starting launcher')
    worker_proc = launch(WORKER_ONCE)


def main() -> int:
    global backend_proc, worker_proc

    setup_logging()
    atexit.register(on_exit)
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    log(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] runtime supervisor start")
    log(f"HOME={os.environ.get('HOME', '')}")
    log(f"PWD={os.getcwd()}")
    os.chdir(REPO_ROOT)
    log(f"cwd={REPO_ROOT}")
    log(f"[supervisor] intervalSeconds={INTERVAL_SECONDS:g}")

    ensure_singleton()

    while not stop_requested:
        backend_proc = reap('backend', backend_proc)
        worker_proc = reap('worker', worker_proc)
        ensure_backend()
        ensure_worker()
        time.sleep(INTERVAL_SECONDS)

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
