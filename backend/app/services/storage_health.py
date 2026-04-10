from datetime import datetime
from pathlib import Path
from typing import Dict

from ..core.settings import settings


def _today_bucket() -> str:
    return datetime.utcnow().strftime('%Y-%m-%d')


def required_storage_paths() -> Dict[str, Path]:
    root = Path(settings.storage_root).expanduser()
    bucket = _today_bucket()
    return {
        'root': root,
        'input': root / 'input' / bucket,
        'feedbackLogs': root / 'logs' / 'feedback' / bucket,
        'failureLogs': root / 'logs' / 'failures' / bucket,
        'failed': root / 'failed' / bucket,
    }


def storage_health_check(create_probe: bool = False) -> dict:
    paths = required_storage_paths()
    details = {}
    writable = True
    errors = []

    for name, path in paths.items():
        try:
            path.mkdir(parents=True, exist_ok=True)
            details[name] = str(path)
        except Exception as error:  # pragma: no cover - surface exact runtime failure
            writable = False
            details[name] = str(path)
            errors.append(f'{name}: {error}')

    if create_probe and writable:
        probe = paths['input'] / '.wimc-write-probe'
        try:
            probe.write_text('ok', encoding='utf-8')
            probe.unlink(missing_ok=True)
        except Exception as error:  # pragma: no cover - surface exact runtime failure
            writable = False
            errors.append(f'probe: {error}')

    return {
        'storageRoot': str(paths['root']),
        'writable': writable,
        'paths': details,
        'errors': errors,
    }


def ensure_storage_ready() -> dict:
    report = storage_health_check(create_probe=True)
    if not report['writable']:
        message = '; '.join(report['errors']) or 'storage volume is not writable'
        raise RuntimeError(f'Cartly storage preflight failed: {message}')
    return report
