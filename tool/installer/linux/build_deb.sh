#!/usr/bin/env bash
# F1 Tracker — .deb kurulum paketi oluşturur.
set -euo pipefail

VERSION="1.6.5"
SRC="${1:-build/linux/x64/release/bundle}"
OUT="f1-tracker_${VERSION}_amd64.deb"

if [ ! -d "$SRC" ]; then
  echo "Linux bundle bulunamadı: $SRC" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PKG="$WORK/f1-tracker_${VERSION}_amd64"
mkdir -p "$PKG/DEBIAN" "$PKG/opt/f1-tracker" \
         "$PKG/usr/share/applications" \
         "$PKG/usr/share/icons/hicolor/scalable/apps"

cp -a "$SRC/." "$PKG/opt/f1-tracker/"

cat > "$PKG/DEBIAN/control" <<EOF
Package: f1-tracker
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Idris Katar <idris.katar@users.noreply.github.com>
Homepage: https://github.com/idriskatar/F1
Description: Unofficial Formula 1 tracker (desktop)
 Calendar, results, news and session replay with an offline cache.
EOF

cat > "$PKG/usr/share/applications/f1-tracker.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=F1 Tracker
Comment=Formula 1 takip uygulaması
Exec=/opt/f1-tracker/f1_tracker
Icon=f1-tracker
Categories=Sports;Utility;
Terminal=false
EOF

cat > "$PKG/usr/share/icons/hicolor/scalable/apps/f1-tracker.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="12" fill="#E10600"/>
  <text x="32" y="43" font-family="sans-serif" font-size="28" font-weight="bold" fill="#ffffff" text-anchor="middle">F1</text>
</svg>
EOF

dpkg-deb --build --root-owner-group "$PKG" "$OUT"
echo "$OUT oluşturuldu"
