import subprocess
from uuid import uuid4

from fastapi import Depends, UploadFile

from ..core.settings import settings
from ..deps import admin_token_dep

ADMIN_ROUTE_DEP = [Depends(admin_token_dep)]

_ALLOWED_IMAGE_TYPES = {
    'image/png': '.png',
    'image/webp': '.webp',
    'image/svg+xml': '.svg',
    'image/jpeg': '.jpg',
}


def worker_running() -> bool:
    try:
        result = subprocess.run(
            ['pgrep', '-f', 'worker_daemon.py'],
            capture_output=True,
            text=True,
            check=False,
        )
        return result.returncode == 0 and bool(result.stdout.strip())
    except Exception:
        return False


def save_asset(file: UploadFile, target_dir, public_prefix: str):
    content_type = (file.content_type or '').lower().strip()
    ext = _ALLOWED_IMAGE_TYPES.get(content_type)
    if ext is None:
        return {
            'ok': False,
            'error': {
                'code': 'UNSUPPORTED_FILE_TYPE',
                'message': 'PNG, JPG, WEBP, SVG 파일만 업로드할 수 있어',
            },
        }

    content = file.file.read()
    if len(content) > 8 * 1024 * 1024:
        return {
            'ok': False,
            'error': {
                'code': 'FILE_TOO_LARGE',
                'message': '8MB 이하 파일만 업로드할 수 있어',
            },
        }

    file_name = f'{uuid4().hex}{ext}'
    target = target_dir / file_name
    target.write_bytes(content)

    api_base = settings.api_base_url.rstrip('/')
    return {
        'ok': True,
        'data': {
            'fileName': file_name,
            'url': f'{api_base}{public_prefix}/{file_name}',
            'contentType': content_type,
            'size': len(content),
            'storagePath': str(target),
        },
    }
