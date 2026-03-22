import json
import os
import re
import shutil
from datetime import datetime
from typing import Optional

import pytesseract
from PIL import Image, ImageEnhance, ImageOps
from sqlalchemy import select
from sqlalchemy.orm import Session as OrmSession

from ..core.settings import settings
from ..db.models import ScanJob
from .scan_service import log_scan_failure

MODEL_VERSION = 'tesseract-kor-eng-v1'
PARSER_VERSION = 'label-parser-v1'
OCR_LANG = 'kor+eng'


def _today_bucket() -> str:
    return datetime.utcnow().strftime('%Y-%m-%d')


def _ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def _output_path(job_id: str) -> str:
    bucket = _today_bucket()
    out_dir = os.path.join(settings.storage_root, 'output', bucket)
    _ensure_dir(out_dir)
    return os.path.join(out_dir, f'{job_id}.json')


def _archive_path(job_id: str, original_path: str) -> str:
    bucket = _today_bucket()
    ext = os.path.splitext(original_path)[1] or '.jpg'
    archive_dir = os.path.join(settings.storage_root, 'archive', bucket)
    _ensure_dir(archive_dir)
    return os.path.join(archive_dir, f'{job_id}{ext}')


def _failed_output_path(job_id: str) -> str:
    bucket = _today_bucket()
    failed_dir = os.path.join(settings.storage_root, 'failed', bucket)
    _ensure_dir(failed_dir)
    return os.path.join(failed_dir, f'{job_id}.json')


def get_next_queued_job(db: OrmSession) -> Optional[ScanJob]:
    stmt = (
        select(ScanJob)
        .where(ScanJob.status == 'queued')
        .order_by(ScanJob.created_at.asc())
        .limit(1)
    )
    return db.scalar(stmt)


def _ocr_text(image_path: str) -> str:
    image = Image.open(image_path).convert('RGB')
    width, height = image.size
    long_side = max(width, height)
    if long_side < 1800:
        scale = 1800 / long_side
        image = image.resize((int(width * scale), int(height * scale)))

    variants = []
    gray = ImageOps.grayscale(image)
    variants.append(gray)
    variants.append(ImageOps.autocontrast(gray))

    enhanced = ImageEnhance.Contrast(gray).enhance(1.4)
    enhanced = ImageEnhance.Sharpness(enhanced).enhance(1.2)
    variants.append(enhanced)

    texts = []
    for img in variants:
        for psm in ('6', '11'):
            try:
                text = pytesseract.image_to_string(
                    img,
                    lang=OCR_LANG,
                    config=f'--psm {psm}',
                ).strip()
                if text:
                    texts.append(text)
            except Exception:
                continue

    merged = []
    seen = set()
    for chunk in texts:
        for line in chunk.splitlines():
            t = ' '.join(line.split()).strip()
            if not t:
                continue
            if t not in seen:
                seen.add(t)
                merged.append(t)
    return '\n'.join(merged)


def _parse_price(text: str) -> Optional[int]:
    won_pattern = re.compile(r'(\d{1,3}(?:,\d{3})+|\d{4,7})\s*원')
    number_pattern = re.compile(r'(\d{1,3}(?:,\d{3})+|\d{4,7})')
    candidates = []

    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue

        won_match = won_pattern.search(line)
        if won_match:
            raw = won_match.group(1).replace(',', '')
            value = int(raw)
            if 500 <= value <= 5000000:
                candidates.append(value)
            continue

        for match in number_pattern.finditer(line):
            raw = match.group(1).replace(',', '')
            try:
                value = int(raw)
            except ValueError:
                continue
            if value < 500 or value > 5000000:
                continue
            if len(raw) >= 6 and value >= 100000:
                continue
            candidates.append(value)

    if not candidates:
        return None
    candidates.sort()
    return candidates[-1]


def _parse_sku(text: str) -> Optional[str]:
    match = re.search(r'\b(\d{6,7})\b', text)
    return match.group(1) if match else None


def _has_letter(line: str) -> bool:
    return bool(re.search(r'[가-힣A-Za-z]', line))


def _korean_count(line: str) -> int:
    return len(re.findall(r'[가-힣]', line))


def _cleanup_line(line: str) -> str:
    line = re.sub(r'\s+', ' ', line).strip()
    line = re.sub(r'[|•·]+', ' ', line)
    return re.sub(r'\s+', ' ', line).strip()


def _parse_name(text: str, sku: Optional[str], price: Optional[int]) -> str:
    bad_words = ('할인', '행사', '기간', '원산지', '규격', '단가', '유통', '문의', '적용', '회원')
    lines = [_cleanup_line(x) for x in text.splitlines() if _cleanup_line(x)]
    picks = []
    for line in lines:
        if not _has_letter(line):
            continue
        if sku and sku in line:
            continue
        if any(word in line for word in bad_words):
            continue
        if re.fullmatch(r'\d+', line):
            continue
        if price is not None and str(price) in line.replace(',', ''):
            continue
        picks.append(line)

    if not picks:
        return ''

    picks.sort(key=lambda line: (_korean_count(line), len(line)), reverse=True)
    best = picks[0]
    if len(picks) > 1 and _korean_count(best) == 0 and _korean_count(picks[1]) > 0:
        best = picks[1]
    return best[:80].strip()


def _estimate_confidence(name: str, price: Optional[int], text: str) -> float:
    score = 0.15
    if name:
        score += 0.2
    if price is not None:
        score += 0.2
    if '원' in text or '₩' in text:
        score += 0.2
    if _korean_count(name) >= 2:
        score += 0.1
    if len(name) >= 4:
        score += 0.05
    lines = [x.strip() for x in text.splitlines() if x.strip()]
    if 1 <= len(lines) <= 12:
        score += 0.05
    noisy = len(re.findall(r'[^\w\s가-힣₩,.-]', text))
    if noisy > 30:
        score -= 0.15
    return round(max(0.0, min(score, 0.9)), 2)


def _looks_like_label(name: str, price: Optional[int], text: str, sku: Optional[str]) -> bool:
    if not name or price is None:
        return False
    if len(name) < 3:
        return False
    if _korean_count(name) == 0 and not re.search(r'[A-Za-z]{3,}', name):
        return False
    lines = [x.strip() for x in text.splitlines() if x.strip()]
    if len(lines) > 25:
        return False
    if ('원' not in text and '₩' not in text) and price < 3000:
        return False
    noisy = len(re.findall(r'[^\w\s가-힣₩,.-]', text))
    if noisy > 40:
        return False
    if sku is None and _korean_count(name) < 2 and price < 3000:
        return False
    return True


def _write_json(path: str, payload: dict) -> None:
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def process_next_job(db: OrmSession) -> Optional[ScanJob]:
    job = get_next_queued_job(db)
    if job is None:
        return None

    job.status = 'processing'
    job.started_at = datetime.utcnow()
    job.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(job)

    try:
        if not job.source_image_path or not os.path.exists(job.source_image_path):
            raise FileNotFoundError('source image not found')

        raw_text = _ocr_text(job.source_image_path)
        price = _parse_price(raw_text)
        sku = _parse_sku(raw_text)
        name = _parse_name(raw_text, sku=sku, price=price)

        if not _looks_like_label(name, price, raw_text, sku):
            failure_payload = {
                'jobId': job.id,
                'status': 'failed',
                'createdAt': job.created_at.isoformat() if job.created_at else None,
                'finishedAt': datetime.utcnow().isoformat(),
                'error': {
                    'code': 'OCR_PARSE_FAILED',
                    'message': '가격 또는 상품명을 충분히 읽지 못했어요',
                },
                'debug': {
                    'rawText': raw_text,
                    'modelVersion': MODEL_VERSION,
                    'parserVersion': PARSER_VERSION,
                },
            }
            _write_json(_failed_output_path(job.id), failure_payload)
            job.status = 'failed'
            job.error_code = 'OCR_PARSE_FAILED'
            job.error_message = '가격 또는 상품명을 충분히 읽지 못했어요'
            job.finished_at = datetime.utcnow()
            job.updated_at = datetime.utcnow()
            db.commit()
            db.refresh(job)
            log_scan_failure(
                db=db,
                job_id=job.id,
                user_id=job.user_id,
                stage='ocr_parse',
                error_code=job.error_code,
                error_message=job.error_message,
                details={
                    'rawText': raw_text,
                    'modelVersion': MODEL_VERSION,
                    'parserVersion': PARSER_VERSION,
                },
            )
            return job

        confidence = _estimate_confidence(name, price, raw_text)
        result = {
            'jobId': job.id,
            'status': 'done',
            'createdAt': job.created_at.isoformat() if job.created_at else None,
            'finishedAt': datetime.utcnow().isoformat(),
            'result': {
                'name': name,
                'price': price,
                'sku': sku,
                'confidence': confidence,
                'source': 'nas-ai-tesseract',
                'rawText': raw_text,
            },
            'meta': {
                'modelVersion': MODEL_VERSION,
                'parserVersion': PARSER_VERSION,
                'ocrLang': OCR_LANG,
            },
        }
        _write_json(_output_path(job.id), result)

        if os.path.exists(job.source_image_path):
            shutil.copy2(job.source_image_path, _archive_path(job.id, job.source_image_path))

        job.status = 'done'
        job.error_code = None
        job.error_message = None
        job.finished_at = datetime.utcnow()
        job.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(job)
        return job
    except Exception as e:
        job.status = 'failed'
        job.error_code = 'WORKER_FAILED'
        job.error_message = str(e)
        job.finished_at = datetime.utcnow()
        job.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(job)
        log_scan_failure(
            db=db,
            job_id=job.id,
            user_id=job.user_id,
            stage='worker_runtime',
            error_code=job.error_code,
            error_message=job.error_message,
            details=None,
        )
        return job


def read_result(job_id: str) -> Optional[dict]:
    bucket = _today_bucket()
    path = os.path.join(settings.storage_root, 'output', bucket, f'{job_id}.json')
    if not os.path.exists(path):
        return None
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)
