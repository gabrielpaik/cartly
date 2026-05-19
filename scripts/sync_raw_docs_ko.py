#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from sync_raw_docs_common import DOCS, KR_ROOT, OLD_ROOT, ensure_parent, remove_unknown_markdown, render_list_field, render_scalar_field, source_updated_at, split_frontmatter

PRESERVE_KEYS = {
    'related',
    'related_dashboard',
    'related_product',
    'related_ocr',
    'related_ui',
    'related_api',
    'related_db',
    'related_issues',
    'related_meeting',
    'priority',
    'owner',
    'next_action',
}
MANAGED_KEYS = {
    'tags', 'aliases', 'topics', 'status', 'area', 'kind', 'language', 'title',
    'source_root', 'source_path', 'source_updated_at', 'paired_english_path', 'paired_korean_path'
}


def normalize_frontmatter(path: Path, entry) -> bool:
    text = path.read_text(encoding='utf-8')
    groups, body = split_frontmatter(text)
    if not groups:
        raise RuntimeError(f'frontmatter missing: {path}')

    kept_groups: list[list[str]] = []
    for key, lines in groups.items():
        if key in MANAGED_KEYS:
            continue
        if key in PRESERVE_KEYS:
            kept_groups.append(lines)
        elif key in {'aliases', 'topics'}:
            continue

    new_lines: list[str] = ['---']
    new_lines.extend(render_list_field('tags', entry.tags_ko))
    new_lines.extend(render_list_field('aliases', entry.aliases))
    new_lines.extend(render_list_field('topics', entry.topics_ko))
    for lines in kept_groups:
        new_lines.extend(lines)
    new_lines.extend(render_scalar_field('status', '활성'))
    new_lines.extend(render_scalar_field('area', entry.area_ko))
    new_lines.extend(render_scalar_field('kind', entry.kind_ko))
    new_lines.extend(render_scalar_field('language', 'ko'))
    new_lines.extend(render_scalar_field('title', entry.title_ko))
    if entry.source_rel:
        new_lines.extend(render_scalar_field('source_root', 'dev_cartly'))
        new_lines.extend(render_scalar_field('source_path', entry.source_rel))
        existing_updated = groups.get('source_updated_at', [])
        if existing_updated:
            new_lines.extend(existing_updated)
        else:
            updated = source_updated_at(entry)
            if updated:
                new_lines.extend(render_scalar_field('source_updated_at', updated))
    new_lines.extend(render_scalar_field('paired_english_path', f'Cartly_md_en_latest/{entry.rel_path}'))
    new_lines.append('---')
    output = '\n'.join(new_lines) + '\n\n' + body.lstrip('\n')
    if output != text:
        path.write_text(output, encoding='utf-8')
        return True
    return False


def main() -> int:
    KR_ROOT.mkdir(parents=True, exist_ok=True)
    OLD_ROOT.mkdir(parents=True, exist_ok=True)
    for folder in ['00_Dashboard', '01_Product', '02_OCR', '03_UIUX', '04_API', '05_DB']:
        (KR_ROOT / folder).mkdir(parents=True, exist_ok=True)

    removed = remove_unknown_markdown(KR_ROOT)
    updated = 0
    missing: list[str] = []
    for entry in DOCS:
        path = KR_ROOT / entry.rel_path
        if not path.exists():
            missing.append(entry.rel_path)
            continue
        if normalize_frontmatter(path, entry):
            updated += 1

    for folder in ['06_Issues', '07_Meeting', '08_Archive']:
        p = KR_ROOT / folder
        if p.exists():
            for child in p.rglob('*'):
                if child.is_file():
                    target = OLD_ROOT / child.relative_to(KR_ROOT)
                    ensure_parent(target)
                    if target.exists():
                        target.unlink()
                    child.rename(target)
            for child in sorted(p.rglob('*'), reverse=True):
                if child.is_dir():
                    try:
                        child.rmdir()
                    except OSError:
                        pass
            try:
                p.rmdir()
            except OSError:
                pass

    print(f'ko_docs={len(DOCS)} updated={updated} moved_old={removed} missing={len(missing)}')
    if missing:
        print('missing_paths=' + ','.join(missing))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
