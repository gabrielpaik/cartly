#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

SAFE_PATH = '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'


def main() -> int:
    if len(sys.argv) < 2:
        print('usage: spawn_detached.py <script> [cwd] [args...]', file=sys.stderr)
        return 2

    script = Path(sys.argv[1]).expanduser().resolve()
    if not script.exists():
        print(f'script not found: {script}', file=sys.stderr)
        return 2

    has_explicit_cwd = len(sys.argv) >= 3
    cwd = Path(sys.argv[2]).expanduser().resolve() if has_explicit_cwd else script.parent
    extra_args = sys.argv[3:] if has_explicit_cwd else sys.argv[2:]

    env = dict(os.environ)
    current_path = env.get('PATH', '')
    env['PATH'] = f'{SAFE_PATH}:{current_path}' if current_path else SAFE_PATH

    proc = subprocess.Popen(
        [str(script), *extra_args],
        cwd=str(cwd),
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        close_fds=True,
        env=env,
    )
    print(proc.pid)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
