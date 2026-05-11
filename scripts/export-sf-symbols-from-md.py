#!/usr/bin/env python3
import re
import subprocess
from pathlib import Path

ROOT = Path('/Users/sdpaik/dev/cartly')
MD_PATH = Path('/Volumes/downloads/MATERIAL_ICONS_TODO_v2.md')
OUT_DIR = ROOT / 'assets' / 'icons' / 'sf'
SFSYM = Path.home() / '.local' / 'bin' / 'sfsym'


def parse_symbols() -> list[str]:
    text = MD_PATH.read_text(encoding='utf-8')
    symbols: list[str] = []
    in_unique_summary = False
    for line in text.splitlines():
        if line.strip() == '## 유니크 매핑 요약':
            in_unique_summary = True
            continue
        if in_unique_summary:
            continue
        if not line.startswith('|'):
            continue
        cells = [cell.strip() for cell in line.strip().split('|')[1:-1]]
        if len(cells) != 3:
            continue
        if cells[0] in {'위치', 'Flutter Icon'} or cells[2] == 'SF Symbol':
            continue
        matches = re.findall(r'`([^`]+)`', cells[2])
        if not matches:
            continue
        symbols.extend(matches)
    deduped: list[str] = []
    seen: set[str] = set()
    for symbol in symbols:
        if symbol in seen:
            continue
        seen.add(symbol)
        deduped.append(symbol)
    return deduped


def export_symbol(symbol: str) -> None:
    output = OUT_DIR / f'{symbol}.svg'
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            str(SFSYM),
            'export',
            symbol,
            '--format',
            'svg',
            '--size',
            '64',
            '-o',
            str(output),
        ],
        check=True,
    )


def main() -> None:
    if not MD_PATH.exists():
        raise SystemExit(f'mapping file not found: {MD_PATH}')
    if not SFSYM.exists():
        raise SystemExit(f'sfsym not found: {SFSYM}')
    symbols = parse_symbols()
    failures: list[str] = []
    for symbol in symbols:
        try:
            export_symbol(symbol)
        except subprocess.CalledProcessError:
            failures.append(symbol)
    print(f'exported={len(symbols) - len(failures)} failed={len(failures)}')
    if failures:
        print('failed symbols:')
        for symbol in failures:
            print(symbol)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
