#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEY_PROPS="$ROOT_DIR/android/key.properties"
AAB_PATH="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
KEYTOOL="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
JARSIGNER="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/jarsigner"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-https://scan-api.seoa-nas.com}"
APP_CONFIG_BASE_URL="${APP_CONFIG_BASE_URL:-$PUBLIC_BASE_URL}"

if [[ ! -f "$KEY_PROPS" ]]; then
  echo "missing $KEY_PROPS"
  exit 1
fi

STORE_FILE="$(grep '^storeFile=' "$KEY_PROPS" | sed 's/^storeFile=//')"
STORE_PASSWORD="$(grep '^storePassword=' "$KEY_PROPS" | sed 's/^storePassword=//')"

cd "$ROOT_DIR"
flutter build appbundle --release \
  --dart-define=CARTLY_REMOTE_BASE_URL="$PUBLIC_BASE_URL" \
  --dart-define=CARTLY_APP_CONFIG_BASE_URL="$APP_CONFIG_BASE_URL"

echo
echo "AAB: $AAB_PATH"
echo
"$JARSIGNER" -verify -verbose -certs "$AAB_PATH" | sed -n '1,20p'
echo
"$KEYTOOL" -list -v -keystore "$STORE_FILE" -storepass "$STORE_PASSWORD" | sed -n '1,40p'
