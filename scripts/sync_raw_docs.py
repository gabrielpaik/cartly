#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import shutil
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

DEST_ROOT = Path('/Users/sdpaik/Documents/Obsidian Vault/Cartly/raw_docs')
STATE_DIR = Path('/Users/sdpaik/Library/Application Support/Cartly')
LOG_PATH = STATE_DIR / 'raw-doc-sync-state.json'
DOC_EXTENSIONS = {'.md', '.doc', '.docx'}
CATEGORY_FOLDERS = [
    '00_Dashboard',
    '01_Product',
    '02_OCR',
    '03_UIUX',
    '04_API',
    '05_DB',
    '06_Issues',
    '07_Meeting',
    '08_Archive',
]
CATEGORY_PREFIX = {
    '00_Dashboard': 'Dashboard',
    '01_Product': 'Product',
    '02_OCR': 'OCR',
    '03_UIUX': 'UI',
    '04_API': 'API',
    '05_DB': 'DB',
    '06_Issues': 'Issue',
    '07_Meeting': 'Meeting',
    '08_Archive': 'Archive',
}
AREA_NAME = {
    '00_Dashboard': '대시보드',
    '01_Product': '제품',
    '02_OCR': 'OCR',
    '03_UIUX': 'UIUX',
    '04_API': 'API',
    '05_DB': 'DB',
    '06_Issues': '이슈',
    '07_Meeting': '회의',
    '08_Archive': '보관',
}
BASE_TAGS = {
    '00_Dashboard': ['cartly', 'dashboard'],
    '01_Product': ['cartly', 'product'],
    '02_OCR': ['cartly', 'ocr'],
    '03_UIUX': ['cartly', 'uiux'],
    '04_API': ['cartly', 'api'],
    '05_DB': ['cartly', 'db'],
    '06_Issues': ['cartly', 'issue'],
    '07_Meeting': ['cartly', 'meeting'],
    '08_Archive': ['cartly', 'archive'],
}
UPPER_TOKENS = {
    'api': 'API',
    'ocr': 'OCR',
    'ui': 'UI',
    'ux': 'UX',
    'db': 'DB',
    'cto': 'CTO',
    'ios': 'iOS',
    'wimc': 'WIMC',
    'cartly': 'Cartly',
    'uiux': 'UIUX',
    'nas': 'NAS',
}
SPECIAL_TOKENS = {
    'mlkit': 'MLKit',
    'figma': 'Figma',
    'cloudflare': 'Cloudflare',
    'auth': 'Auth',
    'readme': 'Readme',
    'launchimage': 'LaunchImage',
    'apppreview': 'AppPreview',
    'backend': 'Backend',
    'frontend': 'Frontend',
    'runbook': 'Runbook',
    'handoff': 'Handoff',
    'relayout': 'Relayout',
    'worktree': 'Worktree',
}
TAG_MAP = {
    'admin': 'admin',
    'api': 'api',
    'app': 'app',
    'architecture': 'architecture',
    'archive': 'archive',
    'audit': 'audit',
    'auth': 'auth',
    'backend': 'backend',
    'baseline': 'baseline',
    'boundary': 'boundary',
    'cart': 'cart',
    'cartly': 'cartly',
    'classification': 'classification',
    'cloudflare': 'cloudflare',
    'commercial': 'commercial',
    'compare': 'compare',
    'config': 'config',
    'contract': 'contract',
    'dashboard': 'dashboard',
    'db': 'db',
    'design': 'design',
    'draft': 'draft',
    'evaluation': 'evaluation',
    'execution': 'execution',
    'explore': 'explore',
    'figma': 'figma',
    'flow': 'flow',
    'flutter': 'flutter',
    'frontend': 'frontend',
    'guide': 'guide',
    'growth': 'growth',
    'handoff': 'handoff',
    'icon': 'icon',
    'icons': 'icon',
    'inventory': 'inventory',
    'issue': 'issue',
    'issues': 'issue',
    'launchimage': 'launch-image',
    'meeting': 'meeting',
    'mlkit': 'mlkit',
    'checkpoint': 'checkpoint',
    'nas': 'nas',
    'ocr': 'ocr',
    'operations': 'operations',
    'overview': 'overview',
    'price': 'price',
    'product': 'product',
    'progress': 'progress',
    'push': 'push',
    'proposal': 'proposal',
    'receipt': 'receipt',
    'refactor': 'refactor',
    'relayout': 'relayout',
    'remote': 'remote',
    'renaming': 'renaming',
    'review': 'review',
    'rubric': 'rubric',
    'runbook': 'runbook',
    'scan': 'scan',
    'schema': 'schema',
    'segment': 'segment',
    'seoa': 'seoa',
    'spec': 'spec',
    'status': 'status',
    'tunnel': 'tunnel',
    'ui': 'ui',
    'user': 'user',
    'users': 'user',
    'ux': 'ux',
    'visual': 'visual',
    'wimc': 'wimc',
    'worktree': 'worktree',
}
EXCLUDE_PARTS = {
    '.git',
    '.svn',
    '.hg',
    'node_modules',
    '.next',
    '.dart_tool',
    'build',
    'Pods',
    'DerivedData',
    '.venv',
    '.claude',
    '.idea',
    '.vscode',
    'coverage',
    'dist',
    '__pycache__',
}

SUPPRESSED_MIRROR_KEYS = {
    'dev_cartly:backend/README.md',
    'dev_cartly:docs/ARCHITECTURE.md',
    'dev_cartly:docs/admin-architecture.md',
    'dev_cartly:docs/commercial-architecture.md',
    'dev_cartly:docs/nas-wimc-architecture.md',
    'dev_cartly:docs/CARTLY_ICON_INVENTORY.md',
    'dev_cartly:admin-web/public/app-preview/assets/assets/icons/README.md',
    'dev_cartly:assets/icons/README.md',
    'dev_cartly:docs/2026-05-07-cartly-design-audit-home-explore-current-cart.md',
    'dev_cartly:docs/2026-05-07-cartly-design-evaluation-rubric.md',
    'dev_cartly:docs/2026-05-07-cartly-visual-foundation-v1.md',
    'dev_cartly:docs/figma-design-review.md',
    'dev_cartly:docs/home-vs-explore-boundary.md',
    'dev_cartly:docs/explore-bm-design.md',
    'dev_cartly:docs/admin-remote-access.md',
    'dev_cartly:docs/cloudflare-tunnel-admin-seoa-nas.md',
    'dev_cartly:docs/cloudflare-tunnel-scan-api-seoa-nas.md',
    'dev_cartly:docs/app-config-contract-cto-2026-03-26.md',
    'dev_cartly:docs/auth-provider-flow.md',
    'dev_cartly:docs/BASELINE_AUDIT_2026-04-10.md',
    'dev_cartly:docs/FLUTTER_REFACTOR_STATUS_2026-04-10.md',
    'dev_cartly:docs/WORKTREE_CLASSIFICATION_2026-04-10.md',
}

METADATA_OVERRIDES = {
    'dev_cartly:README.md': {'status': 'active', 'kind': 'overview'},
    'dev_cartly:backend/README.md': {'status': 'reference', 'kind': 'overview'},
    'dev_cartly:docs/EXECUTION_BACKLOG_2026-03-22.md': {'status': 'active', 'kind': 'backlog'},
    'dev_cartly:docs/operations-runbook.md': {'status': 'active', 'kind': 'runbook'},
    'dev_cartly:docs/2026-05-07-ui-progress-handoff.md': {'status': 'reference', 'kind': 'handoff'},
    'dev_cartly:docs/ARCHITECTURE.md': {'status': 'reference', 'kind': 'architecture'},
    'dev_cartly:docs/admin-architecture.md': {'status': 'reference', 'kind': 'architecture'},
    'dev_cartly:docs/commercial-architecture.md': {'status': 'reference', 'kind': 'architecture'},
    'dev_cartly:docs/nas-wimc-architecture.md': {'status': 'reference', 'kind': 'architecture'},
    'dev_cartly:docs/CARTLY_RENAMING_PLAN.md': {'status': 'reference', 'kind': 'plan'},
    'dev_cartly:docs/receipt-compare-v1.md': {'status': 'active', 'kind': 'scope'},
    'dev_cartly:docs/2026-05-11-cartly-admin-relayout-proposal.md': {'status': 'draft', 'kind': 'proposal'},
    'dev_cartly:docs/2026-05-14-users-push-admin-growth-checkpoint-handoff.md': {'status': 'active', 'kind': 'handoff'},
    'dev_cartly:docs/2026-05-14-veteran-operator-admin-audit.md': {'status': 'active', 'kind': 'audit'},
    'dev_cartly:docs/2026-05-07-cartly-design-audit-home-explore-current-cart.md': {'status': 'reference', 'kind': 'audit'},
    'dev_cartly:docs/2026-05-07-cartly-design-evaluation-rubric.md': {'status': 'reference', 'kind': 'rubric'},
    'dev_cartly:docs/2026-05-07-cartly-visual-foundation-v1.md': {'status': 'reference', 'kind': 'foundation'},
    'dev_cartly:docs/admin-frontend-spec.md': {'status': 'reference', 'kind': 'spec'},
    'dev_cartly:docs/CARTLY_DESIGN_GUIDE.md': {'status': 'reference', 'kind': 'guide'},
    'dev_cartly:docs/CARTLY_ICON_INVENTORY.md': {'status': 'reference', 'kind': 'inventory'},
    'dev_cartly:docs/explore-bm-design.md': {'status': 'reference', 'kind': 'design'},
    'dev_cartly:docs/figma-design-review.md': {'status': 'reference', 'kind': 'review'},
    'dev_cartly:docs/home-vs-explore-boundary.md': {'status': 'reference', 'kind': 'boundary'},
    'dev_cartly:admin-web/public/app-preview/assets/assets/icons/README.md': {'status': 'reference', 'kind': 'asset-reference'},
    'dev_cartly:assets/icons/README.md': {'status': 'reference', 'kind': 'asset-reference'},
    'dev_cartly:docs/api-spec-draft.md': {'status': 'draft', 'kind': 'spec'},
    'dev_cartly:docs/db-schema-draft.md': {'status': 'draft', 'kind': 'schema'},
    'dev_cartly:docs/admin-remote-access.md': {'status': 'active', 'kind': 'runbook'},
    'dev_cartly:docs/app-config-contract-cto-2026-03-26.md': {'status': 'reference', 'kind': 'contract'},
    'dev_cartly:docs/auth-provider-flow.md': {'status': 'reference', 'kind': 'flow'},
    'dev_cartly:docs/cloudflare-tunnel-admin-seoa-nas.md': {'status': 'active', 'kind': 'runbook'},
    'dev_cartly:docs/cloudflare-tunnel-scan-api-seoa-nas.md': {'status': 'active', 'kind': 'runbook'},
    'dev_cartly:docs/BASELINE_AUDIT_2026-04-10.md': {
        'status': 'reference',
        'kind': 'audit',
        'priority': '높음',
        'owner': '미정',
        'next_action': '기준선 점검 결과를 바탕으로 유지할 진전과 정리할 항목을 분리한다.',
    },
    'dev_cartly:docs/FLUTTER_REFACTOR_STATUS_2026-04-10.md': {
        'status': 'reference',
        'kind': 'status',
        'priority': '중간',
        'owner': '미정',
        'next_action': '남은 대형 Flutter 파일과 추가 리팩터링 필요 범위를 다시 점검한다.',
    },
    'dev_cartly:docs/WORKTREE_CLASSIFICATION_2026-04-10.md': {
        'status': 'reference',
        'kind': 'classification',
        'priority': '중간',
        'owner': '미정',
        'next_action': '체크포인트 후보, 플랫폼 변경, 로컬 노이즈를 다시 나눠 커밋 단위를 정리한다.',
    },
    'dev_cartly:ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md': {'status': 'archived', 'kind': 'asset-reference'},
    'external_refs:CARTLY_DESIGN_GUIDE_v2.md': {'status': 'reference', 'kind': 'guide'},
    'external_refs:MATERIAL_ICONS_TODO_v2.md': {'status': 'draft', 'kind': 'todo'},
}

RELATION_FIELD_LABELS = {
    'related_dashboard': '대시보드',
    'related_product': '제품',
    'related_ocr': 'OCR',
    'related_ui': 'UI',
    'related_api': 'API',
    'related_db': 'DB',
    'related_issues': '이슈',
    'related_meeting': '회의',
}

STATUS_LABELS = {
    'active': '활성',
    'draft': '초안',
    'reference': '참고',
    'archived': '보관',
}

KIND_LABELS = {
    'archive': '보관',
    'architecture': '아키텍처',
    'asset-reference': '에셋참고',
    'audit': '점검',
    'backlog': '백로그',
    'board': '보드',
    'boundary': '경계',
    'classification': '분류',
    'contract': '계약',
    'design': '디자인',
    'flow': '플로우',
    'foundation': '비주얼기반',
    'guide': '가이드',
    'handoff': '인계',
    'hub': '허브',
    'inventory': '인벤토리',
    'issue': '이슈',
    'meeting': '회의',
    'note': '노트',
    'overview': '개요',
    'plan': '계획',
    'proposal': '제안',
    'review': '리뷰',
    'rubric': '평가기준',
    'runbook': '런북',
    'schema': '스키마',
    'scope': '범위',
    'spec': '명세',
    'status': '상태',
    'todo': '할일',
}

DISPLAY_TAGS = {
    'active': '활성',
    'admin': '어드민',
    'admin-console': '운영콘솔',
    'admin-page': '어드민페이지',
    'api': 'API',
    'app': '앱',
    'architecture': '아키텍처',
    'archive': '보관',
    'archived': '보관',
    'audit': '점검',
    'auth': '인증',
    'backend': '백엔드',
    'baseline': '베이스라인',
    'board': '보드',
    'boundary': '경계',
    'cart': '카트',
    'cartly': '카틀리',
    'classification': '분류',
    'cloudflare': 'Cloudflare',
    'commercial': '상용화',
    'compare': '비교',
    'config': '설정',
    'contract': '계약',
    'dashboard': '대시보드',
    'data-model': '데이터모델',
    'db': 'DB',
    'design': '디자인',
    'design-system': '디자인시스템',
    'draft': '초안',
    'evaluation': '평가',
    'execution': '실행',
    'explore': '탐색',
    'figma': 'Figma',
    'flow': '플로우',
    'flutter': 'Flutter',
    'frontend': '프론트엔드',
    'guide': '가이드',
    'growth': '그로스',
    'handoff': '인계',
    'hub': '허브',
    'icon': '아이콘',
    'infra': '인프라',
    'integration': '연동',
    'inventory': '인벤토리',
    'issue': '이슈',
    'launch-image': '런치이미지',
    'meeting': '회의',
    'mlkit': 'MLKit',
    'checkpoint': '체크포인트',
    'nas': 'NAS',
    'ocr': 'OCR',
    'operations': '운영',
    'ops': '운영',
    'overview': '개요',
    'price': '가격',
    'product': '제품',
    'progress': '진행',
    'push': '푸시',
    'proposal': '제안',
    'receipt': '영수증',
    'recognition': '인식',
    'reference': '참고',
    'refactor': '리팩터링',
    'relayout': '재배치',
    'remote': '원격',
    'renaming': '리네이밍',
    'review': '리뷰',
    'rubric': '평가기준',
    'runbook': '런북',
    'runtime': '런타임',
    'scan': '스캔',
    'schema': '스키마',
    'segment': '세그먼트',
    'seoa': 'SEOA',
    'source-mirror': '원문참고',
    'spec': '명세',
    'status': '상태',
    'tunnel': '터널',
    'ui': 'UI',
    'uiux': 'UIUX',
    'user': '사용자',
    'ux': 'UX',
    'vision': '비전',
    'visual': '비주얼',
    'wimc': 'WIMC',
    'worktree': '워크트리',
}

DEFAULT_RELATIONS = {
    '00_Dashboard': {'related_product': ['Product-Overview']},
    '01_Product': {'related_api': ['API-Backend-Overview'], 'related_ui': ['UI-Design-Guide']},
    '02_OCR': {'related_api': ['API-Spec-Draft'], 'related_db': ['DB-Schema-Draft'], 'related_ui': ['UI-Design-Guide']},
    '03_UIUX': {'related_product': ['Product-Overview'], 'related_api': ['API-Spec-Draft']},
    '04_API': {'related_product': ['Product-Overview'], 'related_db': ['DB-Schema-Draft']},
    '05_DB': {'related_api': ['API-Spec-Draft'], 'related_product': ['Product-Architecture']},
    '06_Issues': {'related_dashboard': ['Dashboard-2026-05-07-UI-Progress-Handoff'], 'related_ui': ['UI-2026-05-11-Cartly-Admin-Relayout-Proposal']},
    '07_Meeting': {'related_dashboard': ['Dashboard-Execution-Backlog-2026-03-22']},
    '08_Archive': {'related_product': ['Product-Overview']},
}

RELATION_OVERRIDES = {
    'dev_cartly:README.md': {
        'related_dashboard': ['Dashboard-Execution-Backlog-2026-03-22', 'Dashboard-Operations-Runbook'],
        'related_api': ['API-Backend-Overview', 'API-Spec-Draft'],
        'related_ocr': ['OCR-Receipt-Compare-V1'],
        'related_ui': ['UI-Design-Guide'],
    },
    'dev_cartly:backend/README.md': {
        'related_product': ['Product-Overview', 'Product-Architecture'],
        'related_api': ['API-Spec-Draft', 'API-Auth-Provider-Flow'],
        'related_db': ['DB-Schema-Draft'],
    },
    'dev_cartly:docs/EXECUTION_BACKLOG_2026-03-22.md': {
        'related_product': ['Product-Overview'],
        'related_ocr': ['OCR-Receipt-Compare-V1'],
        'related_ui': ['UI-2026-05-11-Cartly-Admin-Relayout-Proposal'],
        'related_api': ['API-Spec-Draft'],
    },
    'dev_cartly:docs/operations-runbook.md': {
        'related_api': ['API-Admin-Remote-Access', 'API-Cloudflare-Tunnel-Admin-Seoa-NAS', 'API-Cloudflare-Tunnel-Scan-API-Seoa-NAS'],
        'related_product': ['Product-Overview'],
    },
    'dev_cartly:docs/2026-05-07-ui-progress-handoff.md': {
        'related_ui': ['UI-2026-05-11-Cartly-Admin-Relayout-Proposal', 'UI-2026-05-07-Cartly-Design-Audit-Home-Explore-Current-Cart'],
        'related_issues': ['Issue-Baseline-Audit-2026-04-10'],
    },
    'dev_cartly:docs/2026-05-14-veteran-operator-admin-audit.md': {
        'related_ui': ['UI-2026-05-11-Cartly-Admin-Relayout-Proposal', 'UI-Admin-Frontend-Spec'],
        'related_dashboard': ['Dashboard-2026-05-14-Users-Push-Admin-Growth-Checkpoint-Handoff', 'Dashboard-Operations-Runbook'],
        'related_product': ['Product-Admin-Architecture'],
    },
    'dev_cartly:docs/ARCHITECTURE.md': {
        'related_api': ['API-Backend-Overview', 'API-Spec-Draft'],
        'related_db': ['DB-Schema-Draft'],
        'related_product': ['Product-Admin-Architecture', 'Product-Commercial-Architecture'],
    },
    'dev_cartly:docs/admin-architecture.md': {
        'related_ui': ['UI-Admin-Frontend-Spec'],
        'related_api': ['API-Backend-Overview'],
        'related_product': ['Product-Architecture'],
    },
    'dev_cartly:docs/commercial-architecture.md': {
        'related_product': ['Product-Overview', 'Product-Renaming-Plan'],
        'related_api': ['API-Spec-Draft'],
    },
    'dev_cartly:docs/nas-wimc-architecture.md': {
        'related_dashboard': ['Dashboard-Operations-Runbook'],
        'related_api': ['API-Backend-Overview', 'API-Cloudflare-Tunnel-Scan-API-Seoa-NAS'],
    },
    'dev_cartly:docs/CARTLY_RENAMING_PLAN.md': {
        'related_product': ['Product-Overview'],
        'related_ui': ['UI-Design-Guide', 'UI-Icon-Inventory'],
    },
    'dev_cartly:docs/receipt-compare-v1.md': {
        'related_api': ['API-Spec-Draft'],
        'related_db': ['DB-Schema-Draft'],
        'related_ui': ['UI-Design-Guide'],
        'related_product': ['Product-Overview'],
    },
    'dev_cartly:docs/2026-05-11-cartly-admin-relayout-proposal.md': {
        'related_ui': ['UI-Admin-Frontend-Spec', 'UI-Design-Guide'],
        'related_product': ['Product-Admin-Architecture'],
        'related_issues': ['Issue-Baseline-Audit-2026-04-10'],
    },
    'dev_cartly:docs/2026-05-14-users-push-admin-growth-checkpoint-handoff.md': {
        'related_ui': ['UI-2026-05-11-Cartly-Admin-Relayout-Proposal', 'UI-Admin-Frontend-Spec'],
        'related_dashboard': ['Dashboard-2026-05-07-UI-Progress-Handoff', 'Dashboard-Operations-Runbook'],
        'related_product': ['Product-Admin-Architecture'],
    },
    'dev_cartly:docs/2026-05-07-cartly-design-audit-home-explore-current-cart.md': {
        'related_ui': ['UI-2026-05-07-Cartly-Design-Evaluation-Rubric', 'UI-2026-05-07-Cartly-Visual-Foundation-V1'],
        'related_issues': ['Issue-Baseline-Audit-2026-04-10'],
    },
    'dev_cartly:docs/2026-05-07-cartly-design-evaluation-rubric.md': {
        'related_ui': ['UI-2026-05-07-Cartly-Design-Audit-Home-Explore-Current-Cart', 'UI-2026-05-07-Cartly-Visual-Foundation-V1'],
    },
    'dev_cartly:docs/2026-05-07-cartly-visual-foundation-v1.md': {
        'related_ui': ['UI-Design-Guide', 'UI-2026-05-07-Cartly-Design-Evaluation-Rubric'],
    },
    'dev_cartly:docs/admin-frontend-spec.md': {
        'related_product': ['Product-Admin-Architecture'],
        'related_api': ['API-Backend-Overview', 'API-Spec-Draft'],
        'related_ui': ['UI-2026-05-11-Cartly-Admin-Relayout-Proposal'],
    },
    'dev_cartly:docs/CARTLY_DESIGN_GUIDE.md': {
        'related_product': ['Product-Overview', 'Product-Renaming-Plan'],
        'related_ui': ['UI-Icon-Inventory', 'UI-Figma-Design-Review'],
    },
    'dev_cartly:docs/CARTLY_ICON_INVENTORY.md': {
        'related_ui': ['UI-Design-Guide', 'UI-AppPreview-Icons', 'UI-Source-Icons'],
    },
    'dev_cartly:docs/explore-bm-design.md': {
        'related_ui': ['UI-Home-Vs-Explore-Boundary', 'UI-Design-Guide'],
        'related_product': ['Product-Overview'],
    },
    'dev_cartly:docs/figma-design-review.md': {
        'related_ui': ['UI-Design-Guide', 'UI-2026-05-07-Cartly-Visual-Foundation-V1'],
    },
    'dev_cartly:docs/home-vs-explore-boundary.md': {
        'related_ui': ['UI-Explore-Bm-Design', 'UI-Design-Guide'],
        'related_product': ['Product-Overview'],
    },
    'dev_cartly:admin-web/public/app-preview/assets/assets/icons/README.md': {
        'related_ui': ['UI-Icon-Inventory', 'UI-Source-Icons'],
    },
    'dev_cartly:assets/icons/README.md': {
        'related_ui': ['UI-Icon-Inventory', 'UI-AppPreview-Icons'],
    },
    'dev_cartly:docs/api-spec-draft.md': {
        'related_db': ['DB-Schema-Draft'],
        'related_api': ['API-Auth-Provider-Flow', 'API-App-Config-Contract-CTO-2026-03-26'],
        'related_ui': ['UI-Admin-Frontend-Spec'],
        'related_ocr': ['OCR-Receipt-Compare-V1'],
    },
    'dev_cartly:docs/db-schema-draft.md': {
        'related_api': ['API-Spec-Draft'],
        'related_ocr': ['OCR-Receipt-Compare-V1'],
        'related_product': ['Product-Architecture'],
    },
    'dev_cartly:docs/admin-remote-access.md': {
        'related_dashboard': ['Dashboard-Operations-Runbook'],
        'related_api': ['API-Cloudflare-Tunnel-Admin-Seoa-NAS'],
    },
    'dev_cartly:docs/app-config-contract-cto-2026-03-26.md': {
        'related_api': ['API-Spec-Draft'],
        'related_product': ['Product-Overview'],
    },
    'dev_cartly:docs/auth-provider-flow.md': {
        'related_api': ['API-Spec-Draft', 'API-App-Config-Contract-CTO-2026-03-26'],
        'related_product': ['Product-Overview'],
    },
    'dev_cartly:docs/cloudflare-tunnel-admin-seoa-nas.md': {
        'related_dashboard': ['Dashboard-Operations-Runbook'],
        'related_api': ['API-Admin-Remote-Access', 'API-Cloudflare-Tunnel-Scan-API-Seoa-NAS'],
    },
    'dev_cartly:docs/cloudflare-tunnel-scan-api-seoa-nas.md': {
        'related_dashboard': ['Dashboard-Operations-Runbook'],
        'related_api': ['API-Cloudflare-Tunnel-Admin-Seoa-NAS', 'API-Spec-Draft'],
    },
    'dev_cartly:docs/BASELINE_AUDIT_2026-04-10.md': {
        'related_ui': ['UI-2026-05-07-Cartly-Design-Audit-Home-Explore-Current-Cart', 'UI-2026-05-11-Cartly-Admin-Relayout-Proposal'],
        'related_dashboard': ['Dashboard-2026-05-07-UI-Progress-Handoff'],
    },
    'dev_cartly:docs/FLUTTER_REFACTOR_STATUS_2026-04-10.md': {
        'related_issues': ['Issue-Worktree-Classification-2026-04-10'],
        'related_dashboard': ['Dashboard-2026-05-07-UI-Progress-Handoff'],
        'related_product': ['Product-Overview'],
    },
    'dev_cartly:docs/WORKTREE_CLASSIFICATION_2026-04-10.md': {
        'related_issues': ['Issue-Flutter-Refactor-Status-2026-04-10'],
        'related_dashboard': ['Dashboard-2026-05-07-UI-Progress-Handoff'],
    },
    'dev_cartly:ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md': {
        'related_ui': ['UI-Design-Guide'],
    },
    'external_refs:CARTLY_DESIGN_GUIDE_v2.md': {
        'related_ui': ['UI-Design-Guide', 'UI-Icon-Inventory'],
        'related_product': ['Product-Overview'],
    },
    'external_refs:MATERIAL_ICONS_TODO_v2.md': {
        'related_ui': ['UI-Icon-Inventory', 'UI-Source-Icons'],
    },
}

SUMMARY_OVERRIDES = {
    'dev_cartly:README.md': [
        '이 문서는 카틀리 저장소 전체를 소개하는 진입 문서다.',
        'Flutter 앱, 어드민 웹, 백엔드, 스크립트가 어디에 있는지 한 번에 파악할 수 있다.',
    ],
    'dev_cartly:backend/README.md': [
        '이 문서는 카틀리 백엔드의 런타임 구조와 주요 책임을 정리한다.',
        'FastAPI, PostgreSQL, NAS 저장소, 스캔 워커가 어떻게 맞물리는지 이해할 때 먼저 보면 좋다.',
    ],
    'dev_cartly:docs/EXECUTION_BACKLOG_2026-03-22.md': [
        '이 문서는 카틀리 초기 실행 백로그와 우선순위를 CTO, CDO, CMO 축으로 나눠 정리한다.',
        'OCR 품질, NAS 기반 처리, UX 개선, 시장 검증을 어떤 순서로 밀어야 하는지 판단할 때 기준이 된다.',
    ],
    'dev_cartly:docs/operations-runbook.md': [
        '이 문서는 카틀리 운영 런타임의 기동, 갱신, 검증 절차를 정리한 런북이다.',
        'Mac mini 로그인 세션 제약과 backend, worker, admin-web의 실제 운영 방식을 빠르게 확인할 수 있다.',
    ],
    'dev_cartly:docs/2026-05-07-ui-progress-handoff.md': [
        '이 문서는 2026-05-07 기준 UI 작업 진행 상황과 사용자 피드백을 넘겨주기 위한 인계 문서다.',
        '무엇을 끝냈고, 무엇이 검증됐고, 어떤 피드백이 다음 수정으로 이어져야 하는지 정리한다.',
    ],
    'dev_cartly:docs/2026-05-14-veteran-operator-admin-audit.md': [
        '이 문서는 2026-05-14 기준 카틀리 어드민을 베테랑 운영자 관점으로 다시 해석한 점검 메모다.',
        'Ads, Explore, Users, Carts, Scan Ops, Config, Content를 각각 어떤 운영 도구로 봐야 하는지와 다음 우선순위를 정리한다.',
    ],
    'dev_cartly:docs/ARCHITECTURE.md': [
        '이 문서는 카틀리 전체 시스템 구조를 앱, 백엔드, 어드민 웹 기준으로 설명한다.',
        '제품 전반의 큰 그림과 레이어 간 책임을 이해할 때 가장 기본이 되는 문서다.',
    ],
    'dev_cartly:docs/admin-architecture.md': [
        '이 문서는 카틀리 어드민의 목적, 사용자 역할, 정보구조를 정의한다.',
        '운영자용 화면을 어떤 원칙과 섹션으로 구성할지 볼 때 참고하는 상위 설계 문서다.',
    ],
    'dev_cartly:docs/commercial-architecture.md': [
        '이 문서는 카틀리를 상용 서비스로 운영할 때 필요한 아키텍처 관점을 정리한다.',
        '계정, 카트 기록, 이벤트 추적, 스캔 처리 같은 상용 요구사항이 시스템 구조에 어떻게 반영되는지 본다.',
    ],
    'dev_cartly:docs/nas-wimc-architecture.md': [
        '이 문서는 NAS 기반 저장소 구조와 폴더 역할을 MVP 기준으로 설명한다.',
        '입력, 출력, 로그, 설정이 어떤 경로에 놓이고 API와 어떻게 연결되는지 파악하는 데 유용하다.',
    ],
    'dev_cartly:docs/CARTLY_RENAMING_PLAN.md': [
        '이 문서는 WIMC에서 Cartly로 외부 브랜드명을 옮기는 전략과 범위를 정리한다.',
        '대규모 폴더 이동 없이 안전하게 리네이밍을 진행하는 이유와 순서를 설명한다.',
    ],
    'dev_cartly:docs/receipt-compare-v1.md': [
        '이 문서는 저장된 카트를 기준으로 영수증을 비교하는 현재 OCR 범위를 설명한다.',
        '항목별 자동 반영은 제외하고, 합계 비교와 영수증 결과 저장에 집중한다는 점이 핵심이다.',
    ],
    'dev_cartly:docs/2026-05-11-cartly-admin-relayout-proposal.md': [
        '이 문서는 카틀리 어드민 레이아웃을 운영 콘솔 중심으로 다시 짜기 위한 제안서다.',
        '전역 IA, 공통 페이지 패턴, 좌우 배치 원칙을 어떻게 가져갈지 정리한다.',
    ],
    'dev_cartly:docs/2026-05-14-users-push-admin-growth-checkpoint-handoff.md': [
        '이 문서는 Users, Push, Ads 중심의 어드민 고도화 작업을 현재 시점에서 안전하게 넘기기 위한 체크포인트 인계 노트다.',
        '승인된 작업 축, 런타임 리셋 상황, 잘못 벗어난 detour, 다음 우선순위를 함께 기록한다.',
    ],
    'dev_cartly:docs/2026-05-07-cartly-design-audit-home-explore-current-cart.md': [
        '이 문서는 홈, 탐색, 현재 카트 화면의 디자인 감사를 점수와 코멘트 중심으로 정리한다.',
        '강점과 약점을 빠르게 파악하고 다음 디자인 개선 우선순위를 잡는 데 쓰인다.',
    ],
    'dev_cartly:docs/2026-05-07-cartly-design-evaluation-rubric.md': [
        '이 문서는 카틀리 디자인을 평가할 때 쓰는 기준표를 정의한다.',
        'Material 3, Apple HIG, LINE, Uber 기준을 참고해 어떤 축으로 점수를 매길지 설명한다.',
    ],
    'dev_cartly:docs/2026-05-07-cartly-visual-foundation-v1.md': [
        '이 문서는 타이포, radius, 색, 강조 단계 같은 비주얼 기반을 정리한다.',
        '지금 UI를 어디서 다운시프트하고 어떤 시각 규율로 맞출지 보는 문서다.',
    ],
    'dev_cartly:docs/admin-frontend-spec.md': [
        '이 문서는 카틀리 어드민 웹의 첫 번째 실사용 스펙을 정리한다.',
        'Overview, Users, Scan Ops 같은 화면이 어떤 테이블과 패널을 가져야 하는지 설명한다.',
    ],
    'dev_cartly:admin-web/public/app-preview/assets/assets/icons/README.md': [
        '이 문서는 앱 프리뷰 자산에서 exact SF Symbols 슬롯을 어떻게 다루는지 설명한다.',
        '근사 아이콘 대체 없이 지정한 심볼을 정확히 매핑하는 원칙이 핵심이다.',
    ],
    'dev_cartly:docs/CARTLY_DESIGN_GUIDE.md': [
        '이 문서는 카틀리 제품 전반의 디자인 가이드를 정리한다.',
        'Home, Explore, My, Login의 역할과 시각 원칙을 함께 설명하는 기준 문서다.',
    ],
    'dev_cartly:docs/explore-bm-design.md': [
        '이 문서는 Explore 탭의 비즈니스 모델과 UX 원칙을 정의한다.',
        '사용자가 비교 비용을 거의 들이지 않고 더 나은 선택을 하게 만드는 흐름에 초점을 둔다.',
    ],
    'dev_cartly:docs/figma-design-review.md': [
        '이 문서는 Figma 기준으로 디자인 리뷰를 반복할 때 지켜야 할 규칙을 정리한다.',
        'Widgetbook, Storybook, Figma를 어떻게 1:1로 맞춰 볼지와 상태 네이밍 원칙을 설명한다.',
    ],
    'dev_cartly:docs/home-vs-explore-boundary.md': [
        '이 문서는 Home과 Explore 탭의 책임 경계를 분명히 하는 문서다.',
        'Home은 실행, Explore는 판단과 전환이라는 한 줄 규칙을 중심으로 흐름을 정리한다.',
    ],
    'dev_cartly:docs/CARTLY_ICON_INVENTORY.md': [
        '이 문서는 현재 아이콘 자산 구조와 교체 우선순위를 정리한다.',
        '런처 아이콘, 알림 아이콘, 브랜드 자산이 어디에 영향을 주는지 빠르게 파악할 수 있다.',
    ],
    'dev_cartly:assets/icons/README.md': [
        '이 문서는 원본 아이콘 자산에서 exact SF Symbols 슬롯을 어떻게 유지하는지 설명한다.',
        '파일명과 실제 심볼명 분리를 포함한 아이콘 운영 원칙을 확인할 수 있다.',
    ],
    'dev_cartly:docs/admin-remote-access.md': [
        '이 문서는 어드민 웹을 외부에서 접근시키는 MVP 보안 구조를 설명한다.',
        'backend는 private로 두고 admin-web만 공개하는 보호 방식이 핵심이다.',
    ],
    'dev_cartly:docs/app-config-contract-cto-2026-03-26.md': [
        '이 문서는 `/v1/app-config` 응답을 어떤 계약으로 다룰지 CTO 관점에서 정의한다.',
        '관리자 설정이 백엔드와 Flutter 앱으로 어떻게 흘러가야 하는지 기준을 세운다.',
    ],
    'dev_cartly:docs/auth-provider-flow.md': [
        '이 문서는 로그인 공급자 흐름을 provider-aware 형태로 바꾸는 방향을 정리한다.',
        'UI, 세션 저장, 백엔드 응답이 공급자 정보를 어떻게 다뤄야 하는지 설명한다.',
    ],
    'dev_cartly:docs/cloudflare-tunnel-admin-seoa-nas.md': [
        '이 문서는 cartly-admin.seoa-nas.com을 Cloudflare Tunnel로 운영하는 구성을 정리한다.',
        '공개되는 경로와 private backend 경계를 어떻게 유지하는지가 핵심이다.',
    ],
    'dev_cartly:docs/cloudflare-tunnel-scan-api-seoa-nas.md': [
        '이 문서는 scan-api.seoa-nas.com 공개 API 경로를 Cloudflare Tunnel로 연결하는 구성을 설명한다.',
        'app-public-proxy가 어떤 안전한 라우트만 backend로 넘기는지 이해하는 데 도움이 된다.',
    ],
    'dev_cartly:docs/api-spec-draft.md': [
        '이 문서는 앱이 사용하는 Cartly API의 초안 명세를 정리한다.',
        '인증, 스캔, 카트, 영수증 같은 주요 엔드포인트와 응답 모양을 빠르게 파악할 수 있다.',
    ],
    'dev_cartly:docs/db-schema-draft.md': [
        '이 문서는 Cartly DB 스키마 초안을 정리한다.',
        'users, sessions, devices, scan_jobs 같은 핵심 테이블이 어떤 필드를 가져야 하는지 설명한다.',
    ],
    'dev_cartly:docs/BASELINE_AUDIT_2026-04-10.md': [
        '이 문서는 2026-04-10 시점 작업트리와 제품 상태를 기준선 점검 관점에서 분류한다.',
        '유지해야 할 진전과 정리해야 할 잡음을 나눠 다음 작업 기준점을 만든다.',
    ],
    'dev_cartly:docs/FLUTTER_REFACTOR_STATUS_2026-04-10.md': [
        '이 문서는 Flutter 리팩터링 작업의 범위와 개선 상태를 정리한다.',
        '작게 나눠 안전하게 정리한 배치와 현재 파일 크기, 커밋 흐름을 확인할 수 있다.',
    ],
    'dev_cartly:docs/WORKTREE_CLASSIFICATION_2026-04-10.md': [
        '이 문서는 워크트리 변경사항을 제품 진전, 플랫폼 스캐폴딩, 로컬 노이즈로 분류한다.',
        '무엇을 체크포인트로 남기고 무엇을 치워야 하는지 빠르게 판단할 수 있다.',
    ],
    'dev_cartly:ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md': [
        '이 문서는 iOS LaunchImage 자산의 위치와 맥락을 설명하는 보관용 메모다.',
        '실제 스플래시 체감은 Flutter 쪽이 더 중요하다는 점을 함께 확인할 수 있다.',
    ],
    'external_refs:CARTLY_DESIGN_GUIDE_v2.md': [
        '이 문서는 외부 기준으로 받은 Cartly 디자인 가이드 v2 문서다.',
        '앱과 어드민을 같은 비주얼 규칙으로 맞출 때 참고하는 상위 기준이다.',
    ],
    'external_refs:MATERIAL_ICONS_TODO_v2.md': [
        '이 문서는 Material 아이콘 관련 후속 작업 TODO를 모아둔 초안 문서다.',
        '아이콘 적용 우선순위와 남은 정리 항목을 확인할 때 참고한다.',
    ],
}


@dataclass(frozen=True)
class SyncRoot:
    name: str
    path: Path
    mode: str = 'tree'
    include_files: tuple[str, ...] = ()


SYNC_ROOTS = [
    SyncRoot(name='dev_cartly', path=Path('/Users/sdpaik/dev/cartly')),
    SyncRoot(
        name='external_refs',
        path=Path('/Volumes/downloads'),
        mode='named-files',
        include_files=(
            'CARTLY_DESIGN_GUIDE_v2.md',
            'MATERIAL_ICONS_TODO_v2.md',
        ),
    ),
]


@dataclass(frozen=True)
class SyncEntry:
    root: str
    source: str
    dest: str


def metadata_key(sync_root: SyncRoot, rel: Path) -> str:
    return f'{sync_root.name}:{rel.as_posix()}'


def get_override(sync_root: SyncRoot, rel: Path) -> dict:
    return METADATA_OVERRIDES.get(metadata_key(sync_root, rel), {})


def is_suppressed(sync_root: SyncRoot, rel: Path) -> bool:
    return metadata_key(sync_root, rel) in SUPPRESSED_MIRROR_KEYS


def should_skip(path: Path) -> bool:
    return bool(set(path.parts) & EXCLUDE_PARTS)


def iter_tree_files(root: Path) -> Iterable[Path]:
    for path in root.rglob('*'):
        if not path.is_file():
            continue
        if should_skip(path):
            continue
        if path.suffix.lower() not in DOC_EXTENSIONS:
            continue
        yield path


def iter_named_files(root: Path, names: tuple[str, ...]) -> Iterable[Path]:
    for name in names:
        path = root / name
        if path.is_file() and path.suffix.lower() in DOC_EXTENSIONS:
            yield path


def detect_category(sync_root: SyncRoot, rel: Path) -> str:
    rel_text = '/'.join(rel.parts).lower()
    name = rel.name.lower()

    if sync_root.name == 'external_refs':
        if 'design' in name or 'icon' in name or 'material' in name:
            return '03_UIUX'
        return '08_Archive'

    if rel == Path('README.md'):
        return '01_Product'
    if rel.parts[:2] == ('backend', 'README.md'):
        return '04_API'
    if rel == Path('docs/2026-05-14-veteran-operator-admin-audit.md'):
        return '03_UIUX'
    if 'launchimage.imageset' in rel_text:
        return '08_Archive'
    if 'assets/icons' in rel_text or 'app-preview/assets/assets/icons' in rel_text:
        return '03_UIUX'

    if any(token in rel_text for token in ['backlog', 'handoff', 'runbook', 'dashboard']):
        return '00_Dashboard'
    if any(token in rel_text for token in ['receipt', 'ocr']):
        return '02_OCR'
    if any(token in rel_text for token in ['design', 'ui', 'ux', 'figma', 'frontend', 'icon', 'relayout', 'boundary', 'visual-foundation']):
        return '03_UIUX'
    if any(token in rel_text for token in ['api-spec', 'app-config-contract', 'auth-provider-flow', 'cloudflare-tunnel', 'remote-access']):
        return '04_API'
    if any(token in rel_text for token in ['db-schema', '/db/']):
        return '05_DB'
    if any(token in rel_text for token in ['audit', 'status', 'classification', 'issue', 'bug']):
        return '06_Issues'
    if any(token in rel_text for token in ['meeting', 'minutes', 'notes']):
        return '07_Meeting'
    if 'architecture' in rel_text or 'renaming' in rel_text or 'commercial' in rel_text:
        return '01_Product'
    return '08_Archive'


def tokenize_text(value: str) -> list[str]:
    return [token for token in re.split(r'[^0-9A-Za-z]+', value) if token]


def format_token(token: str) -> str:
    lower = token.lower()
    if lower in UPPER_TOKENS:
        return UPPER_TOKENS[lower]
    if lower in SPECIAL_TOKENS:
        return SPECIAL_TOKENS[lower]
    if re.fullmatch(r'v\d+', lower):
        return lower.upper()
    if re.fullmatch(r'\d{4}|\d{2}|\d+', token):
        return token
    return token[:1].upper() + token[1:].lower()


def canonical_parts(sync_root: SyncRoot, rel: Path, category: str) -> list[str]:
    rel_text = '/'.join(rel.parts).lower()
    prefix = CATEGORY_PREFIX[category]

    if rel == Path('README.md'):
        return ['Overview']
    if rel.parts[:2] == ('backend', 'README.md'):
        return ['Backend', 'Overview']
    if 'app-preview/assets/assets/icons' in rel_text:
        return ['AppPreview', 'Icons']
    if rel == Path('assets/icons/README.md'):
        return ['Source', 'Icons']
    if 'launchimage.imageset' in rel_text:
        return ['LaunchImage']

    tokens = tokenize_text(rel.stem)
    lowered = [token.lower() for token in tokens]
    removable = {prefix.lower(), 'cartly'}
    if category == '03_UIUX':
        removable.update({'uiux'})
    if category == '06_Issues':
        removable.update({'issue', 'issues'})

    while lowered and lowered[0] in removable:
        lowered.pop(0)
        tokens.pop(0)

    if sync_root.name == 'external_refs' and tokens and tokens[0].lower() == 'material':
        return ['Material', 'Icons', 'Todo', 'V2']

    formatted = [format_token(token) for token in tokens]
    return formatted or ['Doc']


def build_filename(sync_root: SyncRoot, rel: Path, category: str, used: set[str]) -> str:
    prefix = CATEGORY_PREFIX[category]
    parts = canonical_parts(sync_root, rel, category)
    ext = rel.suffix.lower()
    candidate_name = '-'.join([prefix, *parts]) + ext
    candidate = f'{category}/{candidate_name}'
    if candidate not in used:
        used.add(candidate)
        return candidate

    dedupe_parts = [format_token(token) for token in tokenize_text('-'.join(rel.parts[:-1]))]
    dedupe_suffix = '-'.join(dedupe_parts) if dedupe_parts else sync_root.name
    deduped_name = '-'.join([prefix, *parts, dedupe_suffix]) + ext
    deduped = f'{category}/{deduped_name}'
    used.add(deduped)
    return deduped


def infer_kind(category: str, sync_root: SyncRoot, rel: Path, file_stem: str) -> str:
    override = get_override(sync_root, rel)
    if override.get('kind'):
        return str(override['kind'])

    tokens = {token.lower() for token in tokenize_text(file_stem)} | {token.lower() for token in tokenize_text(rel.stem)}
    if category == '08_Archive':
        return 'archive'
    if 'runbook' in tokens:
        return 'runbook'
    if 'backlog' in tokens:
        return 'backlog'
    if 'handoff' in tokens:
        return 'handoff'
    if 'architecture' in tokens:
        return 'architecture'
    if 'spec' in tokens:
        return 'spec'
    if 'schema' in tokens:
        return 'schema'
    if 'guide' in tokens:
        return 'guide'
    if 'review' in tokens:
        return 'review'
    if 'rubric' in tokens:
        return 'rubric'
    if 'audit' in tokens:
        return 'audit'
    if 'inventory' in tokens:
        return 'inventory'
    if 'plan' in tokens:
        return 'plan'
    if 'proposal' in tokens:
        return 'proposal'
    if 'contract' in tokens:
        return 'contract'
    if 'flow' in tokens:
        return 'flow'
    if 'overview' in tokens:
        return 'overview'
    if 'status' in tokens:
        return 'status'
    if 'classification' in tokens:
        return 'classification'
    if category == '06_Issues':
        return 'issue'
    if category == '07_Meeting':
        return 'meeting'
    return 'note'


def infer_status(category: str, sync_root: SyncRoot, rel: Path, file_stem: str) -> str:
    override = get_override(sync_root, rel)
    if override.get('status'):
        return str(override['status'])

    tokens = {token.lower() for token in tokenize_text(file_stem)} | {token.lower() for token in tokenize_text(rel.stem)}
    if category == '08_Archive':
        return 'archived'
    if 'draft' in tokens or 'proposal' in tokens or 'todo' in tokens:
        return 'draft'
    if 'runbook' in tokens or 'backlog' in tokens:
        return 'active'
    if category in {'06_Issues', '07_Meeting'}:
        return 'reference'
    return 'reference'


def display_tag(tag: str) -> str:
    return DISPLAY_TAGS.get(tag, tag)


def build_tags(category: str, rel: Path, file_stem: str, status: str, kind: str) -> list[str]:
    raw_tags: list[str] = []
    for tag in BASE_TAGS[category]:
        if tag not in raw_tags:
            raw_tags.append(tag)

    tokens = tokenize_text(rel.stem) + tokenize_text(file_stem)
    for token in tokens:
        mapped = TAG_MAP.get(token.lower())
        if mapped and mapped not in raw_tags:
            raw_tags.append(mapped)

    derived = [status, kind, 'source-mirror']
    if category == '03_UIUX':
        derived.append('ui')
        if 'design' in raw_tags:
            derived.append('ux')
    if category == '08_Archive':
        derived.append('archived')
    if any(tag in raw_tags for tag in ['cloudflare', 'tunnel', 'remote', 'nas', 'backend']):
        derived.extend(['infra', 'runtime'])
    if any(tag in raw_tags for tag in ['operations', 'runbook', 'dashboard']):
        derived.append('ops')
    if any(tag in raw_tags for tag in ['design', 'figma', 'icon', 'visual', 'guide', 'inventory']):
        derived.append('design-system')
    if any(tag in raw_tags for tag in ['admin', 'frontend', 'relayout']):
        derived.append('admin-console')
        derived.append('admin-page')
    if any(tag in raw_tags for tag in ['receipt', 'ocr', 'scan', 'mlkit']):
        derived.extend(['recognition', 'vision'])
    if any(tag in raw_tags for tag in ['schema', 'db']):
        derived.append('data-model')
    if any(tag in raw_tags for tag in ['spec', 'contract', 'flow', 'api']):
        derived.append('integration')

    for tag in derived:
        if tag and tag not in raw_tags:
            raw_tags.append(tag)

    tags: list[str] = []
    for tag in raw_tags:
        shown = display_tag(tag)
        if shown not in tags:
            tags.append(shown)
    return tags


def build_topics(tags: list[str], category: str) -> list[str]:
    excluded = {display_tag(tag) for tag in BASE_TAGS[category]} | {display_tag('archived')}
    topics = [tag for tag in tags if tag not in excluded]
    return topics


def merge_relations(category: str, sync_root: SyncRoot, rel: Path, alias: str) -> dict[str, list[str]]:
    merged: dict[str, list[str]] = {}
    for field, aliases in DEFAULT_RELATIONS.get(category, {}).items():
        for related_alias in aliases:
            if related_alias == alias:
                continue
            merged.setdefault(field, [])
            if related_alias not in merged[field]:
                merged[field].append(related_alias)

    override = RELATION_OVERRIDES.get(metadata_key(sync_root, rel), {})
    for field, aliases in override.items():
        for related_alias in aliases:
            if related_alias == alias:
                continue
            merged.setdefault(field, [])
            if related_alias not in merged[field]:
                merged[field].append(related_alias)
    return merged


def render_relation_lists(relations: dict[str, list[str]]) -> tuple[list[str], dict[str, list[str]]]:
    all_links: list[str] = []
    relation_links: dict[str, list[str]] = {}
    for field in RELATION_FIELD_LABELS:
        aliases = relations.get(field, [])
        if not aliases:
            continue
        links = [f'[[{alias}]]' for alias in aliases]
        relation_links[field] = links
        for link in links:
            if link not in all_links:
                all_links.append(link)
    return all_links, relation_links


def build_related_section(relation_links: dict[str, list[str]]) -> str:
    if not relation_links:
        return ''
    lines = ['## 관련 문서']
    for field, label in RELATION_FIELD_LABELS.items():
        links = relation_links.get(field)
        if not links:
            continue
        lines.append(f'\n### {label}')
        for link in links:
            lines.append(f'- {link}')
    return '\n\n' + '\n'.join(lines).rstrip() + '\n'


def strip_frontmatter(content: str) -> str:
    if not content.startswith('---\n'):
        return content
    end = content.find('\n---\n', 4)
    if end == -1:
        return content
    return content[end + 5 :].lstrip('\n')


def strip_auto_summary(body: str) -> str:
    start_marker = '<!-- AUTO_SUMMARY_START -->'
    end_marker = '<!-- AUTO_SUMMARY_END -->'
    start = body.find(start_marker)
    end = body.find(end_marker)
    if start == -1 or end == -1 or end < start:
        return body
    return (body[:start] + body[end + len(end_marker):]).strip() + '\n'


def build_summary_lines(category: str, sync_root: SyncRoot, rel: Path, title: str, headings: list[str]) -> list[str]:
    override = SUMMARY_OVERRIDES.get(metadata_key(sync_root, rel))
    if override:
        return override
    lines = [f'이 문서는 {title}를 다루는 {AREA_NAME[category]} 문서다.']
    if headings:
        lines.append('핵심 항목은 ' + ', '.join(headings[:3]) + '이다.')
    return lines


def build_summary_block(summary_lines: list[str]) -> str:
    lines = ['<!-- AUTO_SUMMARY_START -->', '## 한글 요약']
    for line in summary_lines:
        lines.append(f'- {line}')
    lines.append('<!-- AUTO_SUMMARY_END -->')
    return '\n'.join(lines) + '\n\n'


def inject_summary_block(body: str, summary_lines: list[str]) -> str:
    cleaned = strip_auto_summary(body).rstrip() + '\n'
    summary_block = build_summary_block(summary_lines)
    parts = cleaned.splitlines()
    if parts and parts[0].startswith('# '):
        return parts[0] + '\n\n' + summary_block + '\n'.join(parts[1:]).lstrip('\n')
    return summary_block + cleaned


def yaml_scalar(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def render_optional_metadata(sync_root: SyncRoot, rel: Path) -> list[str]:
    override = get_override(sync_root, rel)
    lines: list[str] = []
    if override.get('priority'):
        lines.append(f'우선순위: {yaml_scalar(str(override["priority"]))}')
    if override.get('owner'):
        lines.append(f'담당: {yaml_scalar(str(override["owner"]))}')
    if override.get('next_action'):
        lines.append(f'다음액션: {yaml_scalar(str(override["next_action"]))}')
    return lines


def render_list_field(name: str, values: list[str]) -> list[str]:
    lines = [f'{name}:']
    for value in values:
        lines.append(f'  - {yaml_scalar(value)}')
    return lines


def extract_title(body: str, fallback: str) -> str:
    for line in body.splitlines():
        stripped = line.strip()
        if stripped.startswith('# '):
            return stripped[2:].strip()
    return fallback


def build_title_from_stem(stem: str) -> str:
    return stem.replace('-', ' ')


def build_display_title(category: str, alias: str) -> str:
    parts = alias.split('-')
    prefix = CATEGORY_PREFIX[category]
    if parts and parts[0] == prefix:
        parts = parts[1:]
    translated = []
    for part in parts:
        lower = part.lower()
        shown = DISPLAY_TAGS.get(lower)
        if shown:
            translated.append(shown)
        elif re.fullmatch(r'\d{4}|\d{2}|v\d+', lower):
            translated.append(part.upper() if lower.startswith('v') else part)
        else:
            translated.append(part)
    title_parts = [AREA_NAME[category], *translated]
    return ' '.join(part for part in title_parts if part).strip()


def render_frontmatter(category: str, tags: list[str], topics: list[str], status: str, kind: str, title: str, alias: str, sync_root: SyncRoot, rel: Path, src: Path, all_related_links: list[str], relation_links: dict[str, list[str]]) -> str:
    source_updated_at = datetime.fromtimestamp(src.stat().st_mtime, tz=timezone.utc).isoformat()
    lines = ['---']
    lines.extend(render_list_field('tags', tags))
    lines.extend(render_list_field('aliases', [alias]))
    if topics:
        lines.extend(render_list_field('topics', topics))
    if all_related_links:
        lines.extend(render_list_field('related', all_related_links))
    for field in RELATION_FIELD_LABELS:
        links = relation_links.get(field)
        if links:
            lines.extend(render_list_field(field, links))
    lines.append(f'status: {yaml_scalar(STATUS_LABELS.get(status, status))}')
    lines.append(f'area: {yaml_scalar(AREA_NAME[category])}')
    lines.append(f'kind: {yaml_scalar(KIND_LABELS.get(kind, kind))}')
    lines.append(f'title: {yaml_scalar(title)}')
    lines.extend(render_optional_metadata(sync_root, rel))
    lines.append(f'source_root: {yaml_scalar(sync_root.name)}')
    lines.append(f'source_path: {yaml_scalar(rel.as_posix())}')
    lines.append(f'source_updated_at: {yaml_scalar(source_updated_at)}')
    lines.append('---')
    return '\n'.join(lines) + '\n\n'


def write_markdown(src: Path, dest: Path, category: str, sync_root: SyncRoot, rel: Path) -> bool:
    raw = src.read_text(encoding='utf-8')
    original_body = strip_frontmatter(raw).rstrip() + '\n'
    alias = dest.stem
    source_title = extract_title(original_body, build_title_from_stem(alias))
    title = build_display_title(category, alias)
    headings = [line.strip('# ').strip() for line in original_body.splitlines() if line.startswith('## ')]
    summary_lines = build_summary_lines(category, sync_root, rel, source_title, headings)
    body = inject_summary_block(original_body, summary_lines)
    kind = infer_kind(category, sync_root, rel, alias)
    status = infer_status(category, sync_root, rel, alias)
    tags = build_tags(category, rel, alias, status, kind)
    topics = build_topics(tags, category)
    relations = merge_relations(category, sync_root, rel, alias)
    all_related_links, relation_links = render_relation_lists(relations)
    related_section = build_related_section(relation_links)
    output = render_frontmatter(category, tags, topics, status, kind, title, alias, sync_root, rel, src, all_related_links, relation_links) + body.rstrip() + '\n' + related_section
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.read_text(encoding='utf-8') == output:
        return False
    dest.write_text(output, encoding='utf-8')
    return True


def copy_binary_doc(src: Path, dest: Path) -> bool:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        try:
            same_size = dest.stat().st_size == src.stat().st_size
            same_mtime = int(dest.stat().st_mtime) == int(src.stat().st_mtime)
            if same_size and same_mtime:
                return False
        except FileNotFoundError:
            pass
    shutil.copy2(src, dest)
    return True


def sync_file(src: Path, dest: Path, category: str, sync_root: SyncRoot, rel: Path) -> bool:
    if src.suffix.lower() == '.md':
        return write_markdown(src, dest, category, sync_root, rel)
    return copy_binary_doc(src, dest)


def load_previous_entries() -> list[SyncEntry]:
    if not LOG_PATH.exists():
        return []
    try:
        payload = json.loads(LOG_PATH.read_text(encoding='utf-8'))
    except Exception:
        return []

    entries = payload.get('entries')
    if not isinstance(entries, list):
        return []

    normalized = []
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        root = str(entry.get('root') or '')
        source = str(entry.get('source') or '')
        dest = str(entry.get('dest') or '')
        if root and source and dest:
            normalized.append(SyncEntry(root=root, source=source, dest=dest))
    return normalized


def prune_empty_dirs(root: Path) -> None:
    for path in sorted(root.rglob('*'), reverse=True):
        if not path.is_dir():
            continue
        try:
            next(path.iterdir())
        except StopIteration:
            path.rmdir()
        except Exception:
            continue


def main() -> int:
    DEST_ROOT.mkdir(parents=True, exist_ok=True)
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    for folder in CATEGORY_FOLDERS:
        (DEST_ROOT / folder).mkdir(parents=True, exist_ok=True)

    previous_entries = load_previous_entries()
    copied = 0
    used_dests: set[str] = set()
    new_entries: list[SyncEntry] = []
    available_roots = {root.name for root in SYNC_ROOTS if root.path.exists()}

    for sync_root in SYNC_ROOTS:
        root = sync_root.path
        if not root.exists():
            continue
        files = iter_named_files(root, sync_root.include_files) if sync_root.mode == 'named-files' else iter_tree_files(root)
        for src in files:
            rel = Path(src.name) if sync_root.mode == 'named-files' else src.relative_to(root)
            if is_suppressed(sync_root, rel):
                continue
            category = detect_category(sync_root, rel)
            dest_rel = build_filename(sync_root, rel, category, used_dests)
            dest_abs = DEST_ROOT / dest_rel
            if sync_file(src, dest_abs, category, sync_root, rel):
                copied += 1
            new_entries.append(SyncEntry(root=sync_root.name, source=str(src), dest=dest_rel))

    new_dest_set = {entry.dest for entry in new_entries}
    for entry in previous_entries:
        if entry.dest in new_dest_set:
            continue
        if entry.root not in available_roots and entry.root != 'dev_cartly':
            continue
        target = DEST_ROOT / entry.dest
        if target.exists() and target.is_file():
            target.unlink()

    prune_empty_dirs(DEST_ROOT)
    for folder in CATEGORY_FOLDERS:
        (DEST_ROOT / folder).mkdir(parents=True, exist_ok=True)

    LOG_PATH.write_text(
        json.dumps(
            {
                'syncedFiles': len(new_entries),
                'copiedOrUpdated': copied,
                'roots': [
                    {
                        'name': root.name,
                        'path': str(root.path),
                        'exists': root.path.exists(),
                    }
                    for root in SYNC_ROOTS
                ],
                'entries': [
                    {
                        'root': entry.root,
                        'source': entry.source,
                        'dest': entry.dest,
                    }
                    for entry in new_entries
                ],
            },
            ensure_ascii=False,
            indent=2,
        ) + '\n',
        encoding='utf-8',
    )
    print(f'synced_files={len(new_entries)} copied_or_updated={copied}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
