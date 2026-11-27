#!/usr/bin/env python3
"""Set the installed app display name to "F1 Tracker" on mobile and desktop.

Platform klasörleri (android/, ios/, windows/, linux/, macos/) henüz
oluşturulmamışsa ilgili adımlar sessizce atlanır; betik her durumda başarılı
şekilde biter. Böylece yalnızca masaüstü runner'ları üretildiğinde de
çalıştırılabilir.
"""

from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1]
DISPLAY_NAME = "F1 Tracker"

changed = []
missing = []


def _rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def read(path: Path):
    if not path.exists():
        missing.append(_rel(path))
        return None
    return path.read_text(encoding="utf-8")


def write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")
    changed.append(_rel(path))


def sub_once(path: Path, pattern: str, replacement: str) -> None:
    text = read(path)
    if text is None:
        return
    updated, count = re.subn(pattern, replacement, text, count=1)
    if count:
        write(path, updated)


# Android: uygulama etiketi
sub_once(
    ROOT / "android/app/src/main/AndroidManifest.xml",
    r'(<application\b[^>]*\bandroid:label=")[^"]*(")',
    rf"\g<1>{DISPLAY_NAME}\g<2>",
)

# iOS: görünen ad
info_plist = ROOT / "ios/Runner/Info.plist"
if info_plist.exists():
    with info_plist.open("rb") as file:
        plist = plistlib.load(file)
    plist["CFBundleDisplayName"] = DISPLAY_NAME
    plist["CFBundleName"] = DISPLAY_NAME
    with info_plist.open("wb") as file:
        plistlib.dump(plist, file, sort_keys=False)
    changed.append(_rel(info_plist))
else:
    missing.append(_rel(info_plist))

# Windows: pencere başlığı
sub_once(
    ROOT / "windows/runner/main.cpp",
    r'(window\.Create\(\s*L")[^"]*(")',
    rf"\g<1>{DISPLAY_NAME}\g<2>",
)

# Windows: dosya/ürün açıklaması
runner_rc = ROOT / "windows/runner/Runner.rc"
text = read(runner_rc)
if text is not None:
    updated = re.sub(
        r'(VALUE\s+"(?:FileDescription|ProductName)",\s*")[^"]*(")',
        rf"\g<1>{DISPLAY_NAME}\g<2>",
        text,
    )
    if updated != text:
        write(runner_rc, updated)

# Linux: pencere ve başlık çubuğu başlığı
linux_app = ROOT / "linux/runner/my_application.cc"
text = read(linux_app)
if text is not None:
    updated = re.sub(
        r'((?:gtk_header_bar_set_title|gtk_window_set_title)\([^,]+,\s*")[^"]*(")',
        rf"\g<1>{DISPLAY_NAME}\g<2>",
        text,
    )
    if updated != text:
        write(linux_app, updated)

# macOS: ürün (uygulama) adı
sub_once(
    ROOT / "macos/Runner/Configs/AppInfo.xcconfig",
    r"(?m)^(PRODUCT_NAME[ \t]*=[ \t]*)[^\n]*$",
    rf"\g<1>{DISPLAY_NAME}",
)

# macOS: sandbox içinde dış ağ erişimi (Jolpica, RSS, replay indirmeleri).
for entitlements in (
    ROOT / "macos/Runner/DebugProfile.entitlements",
    ROOT / "macos/Runner/Release.entitlements",
):
    if not entitlements.exists():
        missing.append(_rel(entitlements))
        continue
    text = entitlements.read_text(encoding="utf-8")
    if "com.apple.security.network.client" in text:
        continue
    updated = text.replace(
        "<dict>",
        "<dict>\n\t<key>com.apple.security.network.client</key>\n\t<true/>",
        1,
    )
    if updated != text:
        write(entitlements, updated)

# flutter_secure_storage 10+ requires Android API 23 or newer.
for gradle_file in (ROOT / "android/app/build.gradle.kts", ROOT / "android/app/build.gradle"):
    if not gradle_file.exists():
        continue
    text = gradle_file.read_text(encoding="utf-8")
    text, kotlin_count = re.subn(r"\bminSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", text, count=1)
    text, groovy_count = re.subn(r"\bminSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 23", text, count=1)
    if kotlin_count or groovy_count:
        gradle_file.write_text(text, encoding="utf-8")
        print("Configured Android minimum SDK: 23")
    break

if changed:
    print("Configured app display name: " + DISPLAY_NAME)
    for name in changed:
        print(f"  updated {name}")
else:
    print("No platform files found to configure; run this after 'flutter create'.")

if missing:
    print("Skipped platform files that do not exist yet:")
    for name in missing:
        print(f"  {name}")
