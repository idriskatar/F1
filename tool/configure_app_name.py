#!/usr/bin/env python3
"""Set the installed Android and iOS app display name to F1 Tracker."""

from pathlib import Path
import plistlib
import re


ROOT = Path(__file__).resolve().parents[1]

manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
manifest_text = manifest.read_text(encoding="utf-8")
updated_manifest, count = re.subn(
    r'(<application\b[^>]*\bandroid:label=")[^"]*(")',
    r'\g<1>F1 Tracker\2',
    manifest_text,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f"Could not find android:label in {manifest}")
manifest.write_text(updated_manifest, encoding="utf-8")

info_plist = ROOT / "ios/Runner/Info.plist"
with info_plist.open("rb") as file:
    plist = plistlib.load(file)
plist["CFBundleDisplayName"] = "F1 Tracker"
plist["CFBundleName"] = "F1 Tracker"
with info_plist.open("wb") as file:
    plistlib.dump(plist, file, sort_keys=False)

print("Configured Android and iOS display names: F1 Tracker")

# flutter_secure_storage 10+ requires Android API 23 or newer.
gradle_files = [
    ROOT / "android/app/build.gradle.kts",
    ROOT / "android/app/build.gradle",
]
for gradle_file in gradle_files:
    if not gradle_file.exists():
        continue
    text = gradle_file.read_text(encoding="utf-8")
    text, kotlin_count = re.subn(
        r"\bminSdk\s*=\s*flutter\.minSdkVersion",
        "minSdk = 23",
        text,
        count=1,
    )
    text, groovy_count = re.subn(
        r"\bminSdkVersion\s+flutter\.minSdkVersion",
        "minSdkVersion 23",
        text,
        count=1,
    )
    if kotlin_count or groovy_count:
        gradle_file.write_text(text, encoding="utf-8")
        print("Configured Android minimum SDK: 23")
    break
