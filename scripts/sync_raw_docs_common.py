#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
import re

REPO_ROOT = Path('/Users/sdpaik/dev/cartly')
KR_ROOT = Path('/Users/sdpaik/Documents/Obsidian Vault/Cartly/raw_docs')
EN_ROOT = Path('/Users/sdpaik/Documents/Cartly_md_en_latest')
OLD_ROOT = Path('/Users/sdpaik/Documents/Cartly_md_old')

CATEGORY_DIRS = ['00_Dashboard', '01_Product', '02_OCR', '03_UIUX', '04_API', '05_DB']


@dataclass(frozen=True)
class DocEntry:
    rel_path: str
    area_ko: str
    area_en: str
    kind_ko: str
    kind_en: str
    title_ko: str
    title_en: str
    aliases: tuple[str, ...]
    topics_ko: tuple[str, ...]
    topics_en: tuple[str, ...]
    tags_ko: tuple[str, ...]
    tags_en: tuple[str, ...]
    source_rel: str | None = None

    @property
    def path_parts(self) -> tuple[str, str]:
        parts = self.rel_path.split('/', 1)
        return parts[0], parts[1]

    @property
    def stem(self) -> str:
        return Path(self.rel_path).stem

    @property
    def source_path(self) -> Path | None:
        return REPO_ROOT / self.source_rel if self.source_rel else None


DOCS: tuple[DocEntry, ...] = (
    DocEntry('00_Dashboard/Start-Here.md', '대시보드', 'dashboard', '허브', 'hub', '카틀리 시작점', 'Cartly Start Here', ('Start-Here', 'Cartly-Start'), ('허브',), ('hub',), ('카틀리', '최신', '한글', '대시보드', '허브', '핵심'), ('cartly', 'latest', 'english', 'dashboard', 'hub', 'core')),
    DocEntry('00_Dashboard/Cartly-Hub.md', '대시보드', 'dashboard', '허브', 'hub', '카틀리 허브', 'Cartly Hub', ('Cartly-Hub',), ('허브',), ('hub',), ('카틀리', '최신', '한글', '대시보드', '허브', '핵심'), ('cartly', 'latest', 'english', 'dashboard', 'hub', 'core')),
    DocEntry('00_Dashboard/Admin-Index.md', '대시보드', 'dashboard', '허브', 'hub', '어드민 인덱스', 'Admin Index', ('Admin-Index',), ('허브',), ('hub',), ('카틀리', '최신', '한글', '대시보드', '허브', '핵심', '어드민', '어드민페이지'), ('cartly', 'latest', 'english', 'dashboard', 'hub', 'core', 'admin', 'admin-page')),
    DocEntry('00_Dashboard/Dashboard-Current-State.md', '대시보드', 'dashboard', '현재 상태', 'current-state', '현재 상태', 'Current State', ('Dashboard-Current-State',), ('현재 상태',), ('current-state',), ('카틀리', '최신', '한글', '대시보드', '현재상태'), ('cartly', 'latest', 'english', 'dashboard', 'current-state'), 'docs/CURRENT_STATE.md'),
    DocEntry('00_Dashboard/Dashboard-Release-Management.md', '대시보드', 'dashboard', '릴리즈 관리', 'release-management', '릴리즈 관리', 'Release Management', ('Dashboard-Release-Management',), ('릴리즈 관리',), ('release-management',), ('카틀리', '최신', '한글', '대시보드', '릴리즈'), ('cartly', 'latest', 'english', 'dashboard', 'release-management'), 'docs/07_release/release-management.md'),
    DocEntry('00_Dashboard/Dashboard-Docs-Workflow.md', '대시보드', 'dashboard', '문서 워크플로', 'docs-workflow', '문서 워크플로', 'Docs Workflow', ('Dashboard-Docs-Workflow',), ('문서 워크플로',), ('docs-workflow',), ('카틀리', '최신', '한글', '대시보드', '문서운영'), ('cartly', 'latest', 'english', 'dashboard', 'docs-workflow'), 'docs/DOCS_WORKFLOW.md'),
    DocEntry('00_Dashboard/Dashboard-Admin-Operator-Console.md', '대시보드', 'dashboard', '운영 콘솔', 'operator-console', '어드민 운영 콘솔', 'Admin Operator Console', ('Dashboard-Admin-Operator-Console',), ('운영 콘솔',), ('operator-console',), ('카틀리', '최신', '한글', '대시보드', '어드민', '어드민페이지', '운영콘솔'), ('cartly', 'latest', 'english', 'dashboard', 'admin', 'admin-page', 'operator-console'), 'docs/ADMIN_OPERATOR_CONSOLE.md'),
    DocEntry('00_Dashboard/Dashboard-Infra-System.md', '대시보드', 'dashboard', '인프라 시스템', 'infra-system', '인프라 시스템', 'Infra System', ('Dashboard-Infra-System',), ('인프라 시스템',), ('infra-system',), ('카틀리', '최신', '한글', '대시보드', '인프라', '런타임'), ('cartly', 'latest', 'english', 'dashboard', 'infra', 'runtime'), 'docs/06_infra/infra-system.md'),
    DocEntry('01_Product/Product-App-Product.md', '제품', 'product', '제품', 'product', '앱 제품', 'App Product', ('Product-App-Product',), ('앱 제품',), ('app-product',), ('카틀리', '최신', '한글', '제품', '앱'), ('cartly', 'latest', 'english', 'product', 'app-product'), 'docs/02_product/app-product.md'),
    DocEntry('01_Product/Product-Backend-Architecture.md', '제품', 'product', '아키텍처', 'architecture', '백엔드 아키텍처', 'Backend Architecture', ('Product-Backend-Architecture',), ('백엔드 아키텍처',), ('backend-architecture',), ('카틀리', '최신', '한글', '제품', '백엔드', '아키텍처', '인프라', '런타임'), ('cartly', 'latest', 'english', 'product', 'backend', 'architecture', 'runtime'), 'docs/03_backend/backend-architecture.md'),
    DocEntry('01_Product/Product-Business-Strategy.md', '제품', 'product', '전략', 'strategy', '비즈니스 전략', 'Business Strategy', ('Product-Business-Strategy',), ('비즈니스 전략',), ('business-strategy',), ('카틀리', '최신', '한글', '제품', '전략'), ('cartly', 'latest', 'english', 'product', 'business-strategy'), 'docs/02_product/business-strategy.md'),
    DocEntry('01_Product/Product-Family-Cart-System.md', '제품', 'product', '시스템', 'system', '가족 카트 시스템', 'Family Cart System', ('Product-Family-Cart-System',), ('가족 카트 시스템',), ('family-cart-system',), ('카틀리', '최신', '한글', '제품', '가족공유'), ('cartly', 'latest', 'english', 'product', 'family-cart-system'), 'docs/02_product/family-cart-system.md'),
    DocEntry('02_OCR/OCR-Ai-OCR-System.md', 'OCR', 'ocr', '시스템', 'system', 'AI OCR 시스템', 'AI OCR System', ('OCR-Ai-OCR-System',), ('AI OCR 시스템',), ('ai-ocr-system',), ('카틀리', '최신', '한글', 'OCR', '인식', '비전', '영수증'), ('cartly', 'latest', 'english', 'ocr', 'ai-ocr-system', 'vision', 'receipt'), 'docs/03_backend/ai-ocr-system.md'),
    DocEntry('03_UIUX/UI-Admin-System.md', 'UIUX', 'uiux', '어드민 시스템', 'admin-system', '어드민 시스템', 'Admin System', ('UI-Admin-System',), ('어드민 시스템',), ('admin-system',), ('카틀리', '최신', '한글', 'UIUX', 'UI', '어드민', '어드민페이지'), ('cartly', 'latest', 'english', 'uiux', 'ui', 'admin', 'admin-system', 'admin-page'), 'docs/04_admin/admin-system.md'),
    DocEntry('03_UIUX/UI-App-Design.md', 'UIUX', 'uiux', '앱 디자인', 'app-design', '앱 디자인', 'App Design', ('UI-App-Design',), ('앱 디자인',), ('app-design',), ('카틀리', '최신', '한글', 'UIUX', 'UI', '디자인', '앱', 'UX'), ('cartly', 'latest', 'english', 'uiux', 'ui', 'app-design', 'design', 'ux'), 'docs/02_product/app-design.md'),
    DocEntry('03_UIUX/UI-Brand-System.md', 'UIUX', 'uiux', '브랜드 시스템', 'brand-system', '브랜드 시스템', 'Brand System', ('UI-Brand-System',), ('브랜드 시스템',), ('brand-system',), ('카틀리', '최신', '한글', 'UIUX', 'UI', '브랜드', '디자인'), ('cartly', 'latest', 'english', 'uiux', 'ui', 'brand-system', 'design'), 'docs/01_brand/brand-system.md'),
    DocEntry('03_UIUX/UI-Web-Brand-Design.md', 'UIUX', 'uiux', '웹 브랜드 디자인', 'web-brand-design', '웹 브랜드 디자인', 'Web Brand Design', ('UI-Web-Brand-Design',), ('웹 브랜드 디자인',), ('web-brand-design',), ('카틀리', '최신', '한글', 'UIUX', 'UI', '웹', '브랜드', '디자인'), ('cartly', 'latest', 'english', 'uiux', 'ui', 'web', 'brand-design', 'design'), 'docs/05_web/web-brand-design.md'),
    DocEntry('03_UIUX/UI-Web-Marketing-Pages.md', 'UIUX', 'uiux', '웹 마케팅 페이지', 'web-marketing-pages', '웹 마케팅 페이지', 'Web Marketing Pages', ('UI-Web-Marketing-Pages',), ('웹 마케팅 페이지',), ('web-marketing-pages',), ('카틀리', '최신', '한글', 'UIUX', 'UI', '웹', '마케팅'), ('cartly', 'latest', 'english', 'uiux', 'ui', 'web', 'marketing-pages'), 'docs/05_web/web-marketing-pages.md'),
    DocEntry('03_UIUX/UI-Web-Service.md', 'UIUX', 'uiux', '웹 서비스', 'web-service', '웹 서비스', 'Web Service', ('UI-Web-Service',), ('웹 서비스',), ('web-service',), ('카틀리', '최신', '한글', 'UIUX', 'UI', '웹', '서비스'), ('cartly', 'latest', 'english', 'uiux', 'ui', 'web', 'service'), 'docs/05_web/web-service.md'),
    DocEntry('04_API/API-Realtime-Sync-System.md', 'API', 'api', '실시간 동기화', 'realtime-sync-system', '실시간 동기화 시스템', 'Realtime Sync System', ('API-Realtime-Sync-System',), ('실시간 동기화',), ('realtime-sync-system',), ('카틀리', '최신', '한글', 'API', '동기화', '실시간'), ('cartly', 'latest', 'english', 'api', 'realtime-sync-system', 'sync'), 'docs/03_backend/realtime-sync-system.md'),
    DocEntry('04_API/API-Spec.md', 'API', 'api', '명세', 'spec', 'API 명세', 'API Spec', ('API-Spec',), ('API 명세',), ('api-spec',), ('카틀리', '최신', '한글', 'API', '명세', '연동'), ('cartly', 'latest', 'english', 'api', 'spec', 'integration'), 'docs/03_backend/api-spec.md'),
    DocEntry('05_DB/DB-Database-Schema.md', 'DB', 'db', '스키마', 'schema', '데이터베이스 스키마', 'Database Schema', ('DB-Database-Schema',), ('데이터베이스 스키마',), ('database-schema',), ('카틀리', '최신', '한글', 'DB', '스키마', '데이터모델'), ('cartly', 'latest', 'english', 'db', 'schema', 'data-model'), 'docs/03_backend/database-schema.md'),
)

DOC_MAP = {entry.rel_path: entry for entry in DOCS}
MANIFEST_PATHS = {entry.rel_path for entry in DOCS}

MANUAL_EN_BODIES = {
    '00_Dashboard/Start-Here.md': """# Cartly Start Here\n\n## Documents to read first\n- [[Cartly-Hub]]\n- [[Dashboard-Current-State]]\n- [[Dashboard-Release-Management]]\n- [[Dashboard-Docs-Workflow]]\n- [[Product-App-Product]]\n- [[UI-App-Design]]\n- [[API-Spec]]\n- [[DB-Database-Schema]]\n\n## Entry points by task type\n- Check current state → [[Dashboard-Current-State]]\n- Release and review prep → [[Dashboard-Release-Management]]\n- Documentation operating rules → [[Dashboard-Docs-Workflow]]\n- Understand product structure → [[Product-App-Product]] / [[Product-Backend-Architecture]] / [[Product-Business-Strategy]]\n- Admin structure and operator rules → [[Admin-Index]] / [[Dashboard-Admin-Operator-Console]] / [[UI-Admin-System]]\n- App and UI design rules → [[UI-App-Design]] / [[UI-Brand-System]] / [[UI-Web-Brand-Design]]\n- App-backend contract structure → [[API-Spec]] / [[API-Realtime-Sync-System]]\n- OCR and receipt flow → [[OCR-Ai-OCR-System]]\n- Database structure → [[DB-Database-Schema]]\n\n## When you start a new Claw session\nUse this prompt:\n\n- `Read /Users/sdpaik/Documents/Cartly_md_en_latest/00_Dashboard/Start-Here.md first, then read /Users/sdpaik/Documents/Obsidian Vault/Cartly/raw_docs/00_Dashboard/Start-Here.md, and start from there.`\n\nIntent:\n- The English mirror is the assistant's source-reading path.\n- The Korean docs are the user's reading path.\n- Old docs should stay out of the default reading flow.\n\n## Documents to look at now\n```dataview\nTABLE area AS Area, kind AS Kind, status AS Status, topics AS Topics\nFROM \"Cartly/raw_docs\"\nWHERE contains(tags, \"핵심\")\nAND file.name != this.file.name\nSORT area ASC, file.name ASC\n```\n""",
    '00_Dashboard/Cartly-Hub.md': """# Cartly Hub\n\n## Start here\n- [[Start-Here]]\n\n## Documents to look at now\n```dataview\nTABLE area AS Area, kind AS Kind, status AS Status, topics AS Topics, source_updated_at AS SourceUpdatedAt\nFROM \"Cartly/raw_docs\"\nWHERE file.name != this.file.name\nAND kind != \"허브\"\nSORT area ASC, file.name ASC\n```\n\n## Active documents\n```dataview\nTABLE area AS Area, kind AS Kind, status AS Status, topics AS Topics\nFROM \"Cartly/raw_docs\"\nWHERE file.name != this.file.name\nAND status = \"활성\"\nSORT area ASC, file.name ASC\n```\n\n## Core entry documents\n- [[Dashboard-Current-State]]\n- [[Dashboard-Release-Management]]\n- [[Dashboard-Docs-Workflow]]\n- [[Dashboard-Admin-Operator-Console]]\n- [[Dashboard-Infra-System]]\n- [[Admin-Index]]\n- [[Product-App-Product]]\n- [[Product-Backend-Architecture]]\n- [[Product-Business-Strategy]]\n- [[Product-Family-Cart-System]]\n- [[OCR-Ai-OCR-System]]\n- [[UI-App-Design]]\n- [[UI-Brand-System]]\n- [[UI-Admin-System]]\n- [[UI-Web-Brand-Design]]\n- [[UI-Web-Marketing-Pages]]\n- [[UI-Web-Service]]\n- [[API-Spec]]\n- [[API-Realtime-Sync-System]]\n- [[DB-Database-Schema]]\n\n## Foreground rule\n- Keep only the latest canonical Korean docs and current entry hubs inside the active Obsidian tree.\n- Keep English full mirrors in `/Users/sdpaik/Documents/Cartly_md_en_latest`.\n- Keep old and historical docs in `/Users/sdpaik/Documents/Cartly_md_old`, not inside the visible Obsidian tree.\n""",
    '00_Dashboard/Admin-Index.md': """# Admin Index\n\n## All admin documents\n```dataview\nTABLE area AS Area, kind AS Kind, status AS Status, topics AS Topics, source_updated_at AS SourceUpdatedAt\nFROM \"Cartly/raw_docs\"\nWHERE file.name != this.file.name\nAND contains(tags, \"어드민페이지\")\nSORT status ASC, area ASC, file.name ASC\n```\n\n## Active admin documents\n```dataview\nTABLE area AS Area, kind AS Kind, topics AS Topics, related_api AS RelatedAPI, related_ui AS RelatedUI\nFROM \"Cartly/raw_docs\"\nWHERE file.name != this.file.name\nAND contains(tags, \"어드민페이지\")\nAND status = \"활성\"\nSORT area ASC, file.name ASC\n```\n\n## Core admin documents\n- [[Dashboard-Admin-Operator-Console]]\n- [[UI-Admin-System]]\n- [[Product-Backend-Architecture]]\n- [[API-Spec]]\n- [[Dashboard-Infra-System]]\n""",
}


def source_updated_at(entry: DocEntry) -> str | None:
    if not entry.source_path or not entry.source_path.exists():
        return None
    return datetime.fromtimestamp(entry.source_path.stat().st_mtime, tz=timezone.utc).isoformat()


def split_frontmatter(text: str) -> tuple[dict[str, list[str]], str]:
    if not text.startswith('---\n'):
        return {}, text
    end = text.find('\n---\n', 4)
    if end == -1:
        return {}, text
    frontmatter = text[4:end].splitlines()
    body = text[end + 5 :]
    groups: dict[str, list[str]] = {}
    current_key: str | None = None
    current_lines: list[str] = []
    for line in frontmatter:
        if re.match(r'^[A-Za-z_][A-Za-z0-9_]*:', line):
            if current_key is not None:
                groups[current_key] = current_lines
            current_key = line.split(':', 1)[0]
            current_lines = [line]
        else:
            current_lines.append(line)
    if current_key is not None:
        groups[current_key] = current_lines
    return groups, body


def render_list_field(name: str, values: tuple[str, ...] | list[str]) -> list[str]:
    lines = [f'{name}:']
    for value in values:
        lines.append(f'  - "{value}"')
    return lines


def render_scalar_field(name: str, value: str) -> list[str]:
    return [f'{name}: "{value}"']


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def remove_unknown_markdown(root: Path) -> int:
    removed = 0
    for path in sorted(root.glob('*/*.md')):
        rel = path.relative_to(root).as_posix()
        if rel in MANIFEST_PATHS:
            continue
        target = OLD_ROOT / rel
        ensure_parent(target)
        if target.exists():
            target.unlink()
        path.rename(target)
        removed += 1
    return removed
