#!/usr/bin/env bash
# F1 Tracker — Applications klasörüne sürüklenebilir .dmg oluşturur.
set -euo pipefail

VERSION="1.6.2"
APP="$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' -print -quit)"

if [ -z "$APP" ]; then
  echo "Flutter .app üretmedi" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "F1 Tracker" -srcfolder "$STAGE" -ov -format UDZO "F1-Tracker-v${VERSION}.dmg"
echo "F1-Tracker-v${VERSION}.dmg oluşturuldu"
