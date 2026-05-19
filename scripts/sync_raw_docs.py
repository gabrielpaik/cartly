#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent


def run(script_name: str) -> int:
    script_path = SCRIPT_DIR / script_name
    result = subprocess.run([sys.executable, str(script_path)], check=False)
    return result.returncode


def main() -> int:
    codes = [
        run('sync_raw_docs_ko.py'),
        run('sync_raw_docs_en.py'),
    ]
    if any(code != 0 for code in codes):
        return 1
    print('sync_mode=split ko=raw_docs en=Cartly_md_en_latest old=Cartly_md_old')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
