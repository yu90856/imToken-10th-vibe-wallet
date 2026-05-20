#!/usr/bin/env bash
# 建置供 Sideloadly 簽名安裝的 IPA（未簽名，由 Sideloadly 用你的 Apple ID 簽）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$IOS/build"
APP_NAME="VibeWallet"

echo "→ Sync Token Core…"
"$IOS/scripts/sync-token-core-ios.sh"

echo "→ Release build (iphoneos)…"
xcodebuild -project "$IOS/VibeWallet.xcodeproj" -scheme "$APP_NAME" -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$OUT/DerivedData" \
  build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

APP="$OUT/DerivedData/Build/Products/Release-iphoneos/${APP_NAME}.app"
rm -rf "$OUT/Payload" "$OUT/${APP_NAME}.ipa"
mkdir -p "$OUT/Payload"
cp -R "$APP" "$OUT/Payload/"
( cd "$OUT" && zip -qr "${APP_NAME}.ipa" Payload )

echo "✓ IPA: $OUT/${APP_NAME}.ipa"
ls -lh "$OUT/${APP_NAME}.ipa"
