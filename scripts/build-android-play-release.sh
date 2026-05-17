#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEY_PROPS="$ROOT_DIR/android/key.properties"
AAB_PATH="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
KEYTOOL="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
JARSIGNER="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/jarsigner"

if [[ ! -f "$KEY_PROPS" ]]; then
  echo "missing $KEY_PROPS"
  exit 1
fi

STORE_FILE="$(grep '^storeFile=' "$KEY_PROPS" | sed 's/^storeFile=//')"
STORE_PASSWORD="$(grep '^storePassword=' "$KEY_PROPS" | sed 's/^storePassword=//')"

cd "$ROOT_DIR"
flutter build appbundle --release

echo
echo "AAB: $AAB_PATH"
echo
"$JARSIGNER" -verify -verbose -certs "$AAB_PATH" | sed -n '1,20p'
echo
"$KEYTOOL" -list -v -keystore "$STORE_FILE" -storepass "$STORE_PASSWORD" | sed -n '1,40p'
