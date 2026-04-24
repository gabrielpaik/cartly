#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/admin-preview-web"
TARGET="$ROOT/admin-web/public/app-preview"

rm -rf "$OUT"
flutter build web \
  --release \
  --no-web-resources-cdn \
  --base-href /app-preview/ \
  -t "$ROOT/lib/preview_main.dart" \
  --output "$OUT"

mkdir -p "$TARGET"
rsync -a --delete "$OUT/" "$TARGET/"

python3 - <<'PY'
from pathlib import Path
import re
path = Path("$ROOT/admin-web/public/app-preview/flutter_bootstrap.js")
text = path.read_text()
old = """_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: \"864899412\" /* Flutter's service worker is deprecated and will be removed in a future Flutter release. */
  }
});"""
if old in text:
    text = text.replace(old, "_flutter.loader.load({});")
else:
    text = re.sub(r"_flutter\.loader\.load\(\{\s*serviceWorkerSettings:[\s\S]*?\}\s*\);", "_flutter.loader.load({});", text, count=1)
text = re.sub(r'"builds":\[(\{.*?\}),\{\}\]', r'"builds":[\1]', text, count=1)
text = re.sub(r'builds:\[(\{.*?\}),\{\}\]', r'builds:[\1]', text, count=1)
path.write_text(text)
PY

echo "Preview built to $TARGET"
