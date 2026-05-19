#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from sync_raw_docs_common import DOCS, EN_ROOT, MANUAL_EN_BODIES, render_list_field, render_scalar_field, source_updated_at, split_frontmatter

PRESERVE_KEYS = set()


def english_body(entry) -> str:
    if entry.source_path and entry.source_path.exists():
        text = entry.source_path.read_text(encoding='utf-8')
        _, body = split_frontmatter(text)
        return body.lstrip('\n').rstrip() + '\n'
    manual = MANUAL_EN_BODIES.get(entry.rel_path)
    if manual is None:
        raise RuntimeError(f'No English body source for {entry.rel_path}')
    return manual.rstrip() + '\n'


def render_frontmatter(entry) -> str:
    lines: list[str] = ['---']
    lines.extend(render_list_field('tags', entry.tags_en))
    lines.extend(render_list_field('aliases', entry.aliases))
    lines.extend(render_list_field('topics', entry.topics_en))
    lines.extend(render_scalar_field('status', 'active'))
    lines.extend(render_scalar_field('area', entry.area_en))
    lines.extend(render_scalar_field('kind', entry.kind_en))
    lines.extend(render_scalar_field('language', 'en'))
    lines.extend(render_scalar_field('title', entry.title_en))
    if entry.source_rel:
        lines.extend(render_scalar_field('source_root', 'dev_cartly'))
        lines.extend(render_scalar_field('source_path', entry.source_rel))
        updated = source_updated_at(entry)
        if updated:
            lines.extend(render_scalar_field('source_updated_at', updated))
    lines.extend(render_scalar_field('paired_korean_path', f'raw_docs/{entry.rel_path}'))
    lines.append('---')
    return '\n'.join(lines) + '\n\n'


def main() -> int:
    EN_ROOT.mkdir(parents=True, exist_ok=True)
    for folder in ['00_Dashboard', '01_Product', '02_OCR', '03_UIUX', '04_API', '05_DB']:
        (EN_ROOT / folder).mkdir(parents=True, exist_ok=True)

    expected = {entry.rel_path for entry in DOCS}
    removed = 0
    for path in sorted(EN_ROOT.glob('*/*.md')):
        rel = path.relative_to(EN_ROOT).as_posix()
        if rel in expected:
            continue
        path.unlink()
        removed += 1

    updated = 0
    for entry in DOCS:
        path = EN_ROOT / entry.rel_path
        output = render_frontmatter(entry) + english_body(entry)
        if not path.exists() or path.read_text(encoding='utf-8') != output:
            path.write_text(output, encoding='utf-8')
            updated += 1

    print(f'en_docs={len(DOCS)} updated={updated} removed={removed}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
