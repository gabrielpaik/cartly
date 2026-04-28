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

python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys
import time

root = Path(sys.argv[1])
target = root / 'admin-web/public/app-preview'
bootstrap_path = target / 'flutter_bootstrap.js'
index_path = target / 'index.html'
stamp = str(int(time.time()))

bootstrap = bootstrap_path.read_text()
old = """_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: \"864899412\" /* Flutter's service worker is deprecated and will be removed in a future Flutter release. */
  }
});"""
if old in bootstrap:
    bootstrap = bootstrap.replace(old, "_flutter.loader.load({});")
else:
    bootstrap = re.sub(r"_flutter\.loader\.load\(\{\s*serviceWorkerSettings:[\s\S]*?\}\s*\);", "_flutter.loader.load({});", bootstrap, count=1)
bootstrap = re.sub(r'"builds":\[(\{.*?\}),\{\}\]', r'"builds":[\1]', bootstrap, count=1)
bootstrap = re.sub(r'builds:\[(\{.*?\}),\{\}\]', r'builds:[\1]', bootstrap, count=1)
bootstrap = bootstrap.replace('"mainJsPath":"main.dart.js"', f'"mainJsPath":"main.dart.js?v={stamp}"')
bootstrap_path.write_text(bootstrap)

index = index_path.read_text()
index = index.replace('flutter_bootstrap.js" async', f'flutter_bootstrap.js?v={stamp}" async')
index_path.write_text(index)
PY

echo "Preview built to $TARGET"
