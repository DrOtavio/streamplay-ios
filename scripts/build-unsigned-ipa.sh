#!/usr/bin/env bash
# Requires macOS + Xcode. Generates an unsigned IPA to be re-signed by AltStore/Sideloadly.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DERIVED="$ROOT/.build"
OUT="$ROOT/dist"
mkdir -p "$OUT"
xcodebuild -project StreamPlay.xcodeproj -scheme StreamPlay \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build
APP="$DERIVED/Build/Products/Release-iphoneos/StreamPlay.app"
test -d "$APP"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/StreamPlay.app"
(cd "$STAGE" && /usr/bin/zip -qry "$OUT/StreamPlay-unsigned.ipa" Payload)
echo "IPA unsigned: $OUT/StreamPlay-unsigned.ipa"
echo "This IPA requires legitimate signing/installation; it does not grant CarPlay entitlements."
