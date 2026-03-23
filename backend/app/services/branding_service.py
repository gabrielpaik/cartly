import json
from datetime import datetime
from typing import Any, Dict

from sqlalchemy.orm import Session as OrmSession

from ..db.models import AppSetting

DEFAULT_BRANDING: Dict[str, Any] = {
    'logoType': 'text',
    'logoText': "What's in my cart",
    'logoImageUrl': None,
    'homeSubtitle': '지금 카트 총액을 확인해',
    'savedSubtitle': '저장한 카트를 다시 봐',
    'mySubtitle': '기록을 남기려면 로그인',
    'loginSubtitle': '저장과 기록을 이어가려면 로그인',
    'saveCompleteTitle': '카트 저장 완료',
    'saveCompleteSubtitle': '다음 장보기 전에 다시 볼 수 있어',
}


def get_branding(db: OrmSession) -> Dict[str, Any]:
    row = db.get(AppSetting, 'branding')
    if row is None:
        return DEFAULT_BRANDING.copy()
    try:
        data = json.loads(row.value_json)
    except Exception:
        return DEFAULT_BRANDING.copy()
    merged = DEFAULT_BRANDING.copy()
    merged.update(data or {})
    return merged


def save_branding(db: OrmSession, payload: Dict[str, Any]) -> Dict[str, Any]:
    merged = DEFAULT_BRANDING.copy()
    merged.update(payload or {})
    row = db.get(AppSetting, 'branding')
    if row is None:
        row = AppSetting(key='branding', value_json=json.dumps(merged, ensure_ascii=False), updated_at=datetime.utcnow())
        db.add(row)
    else:
        row.value_json = json.dumps(merged, ensure_ascii=False)
        row.updated_at = datetime.utcnow()
    db.commit()
    return merged
