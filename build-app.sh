#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"
MODE="${1:-preview}"
if [[ "$MODE" != preview && "$MODE" != store ]]; then
    echo 'Usage: ./build-app.sh [preview|store]' >&2
    exit 2
fi

load_submission_setting() {
    python3 - "$1" <<'PY'
import json
import sys
from pathlib import Path

try:
    config = json.loads(Path("AppStore/Submission.local.json").read_text())
    value = config.get(sys.argv[1], "")
except FileNotFoundError:
    value = ""
except (OSError, json.JSONDecodeError):
    print("Could not read local App Store submission settings.", file=sys.stderr)
    raise SystemExit(1)

if isinstance(value, str):
    print(value, end="")
PY
}

if [[ "$MODE" == store ]]; then
    COMMISSIEWIJZER_APP_SIGN_IDENTITY="${COMMISSIEWIJZER_APP_SIGN_IDENTITY:-$(load_submission_setting appSigningIdentity)}"
    COMMISSIEWIJZER_INSTALLER_SIGN_IDENTITY="${COMMISSIEWIJZER_INSTALLER_SIGN_IDENTITY:-$(load_submission_setting installerSigningIdentity)}"
    COMMISSIEWIJZER_PROVISION_PROFILE="${COMMISSIEWIJZER_PROVISION_PROFILE:-$(load_submission_setting provisionProfile)}"
    COMMISSIEWIJZER_TEAM_ID="${COMMISSIEWIJZER_TEAM_ID:-$(load_submission_setting teamID)}"
    export COMMISSIEWIJZER_APP_SIGN_IDENTITY COMMISSIEWIJZER_INSTALLER_SIGN_IDENTITY
    export COMMISSIEWIJZER_PROVISION_PROFILE COMMISSIEWIJZER_TEAM_ID
    : "${COMMISSIEWIJZER_APP_SIGN_IDENTITY:?Set COMMISSIEWIJZER_APP_SIGN_IDENTITY to a Mac App Distribution identity.}"
    : "${COMMISSIEWIJZER_INSTALLER_SIGN_IDENTITY:?Set COMMISSIEWIJZER_INSTALLER_SIGN_IDENTITY to a Mac Installer Distribution identity.}"
    : "${COMMISSIEWIJZER_TEAM_ID:?Set COMMISSIEWIJZER_TEAM_ID to your Apple Developer Team ID.}"
    : "${COMMISSIEWIJZER_PROVISION_PROFILE:?Set COMMISSIEWIJZER_PROVISION_PROFILE to an App Store distribution profile.}"
    mkdir -p "$PROJECT_DIR/.build"
    python3 scripts/store-entitlements.py "$COMMISSIEWIJZER_PROVISION_PROFILE" "$COMMISSIEWIJZER_TEAM_ID" "$PROJECT_DIR/.build/Store.entitlements"
fi

ARCH_ARGS=(--arch arm64)
if [[ "$MODE" == store ]]; then
    ARCH_ARGS=(--arch arm64 --arch x86_64)
fi
if [[ "$MODE" == preview ]]; then
    APP_DIR="$PROJECT_DIR/dist/CommissieWijzer.app"
else
    APP_DIR="$PROJECT_DIR/dist/store/CommissieWijzer.app"
fi

# Release artifacts use a stable compiler path and omit debug symbols so the
# author's workspace path is not embedded in the shipped executable.
swift build -c release "${ARCH_ARGS[@]}" \
    -Xswiftc -file-prefix-map -Xswiftc "$PROJECT_DIR=/CommissieWijzer" \
    -Xcc "-ffile-prefix-map=$PROJECT_DIR=/CommissieWijzer"
BIN_DIR="$(swift build -c release "${ARCH_ARGS[@]}" --show-bin-path)"
# Recreate only the generated bundle; never modify a downloaded provisioning profile.
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp -X "$BIN_DIR/CommissieWijzer" "$APP_DIR/Contents/MacOS/CommissieWijzer.next"
chmod +x "$APP_DIR/Contents/MacOS/CommissieWijzer.next"
mv -f "$APP_DIR/Contents/MacOS/CommissieWijzer.next" "$APP_DIR/Contents/MacOS/CommissieWijzer"
strip -S "$APP_DIR/Contents/MacOS/CommissieWijzer"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>CommissieWijzer</string>
    <key>CFBundleIdentifier</key><string>nl.commissiewijzer.app</string>
    <key>CFBundleName</key><string>CommissieWijzer</string>
    <key>CFBundleDisplayName</key><string>CommissieWijzer</string>
    <key>CFBundleIconFile</key><string>CommissieWijzer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.1.2</string>
    <key>CFBundleVersion</key><string>7</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 CommissieWijzer contributors</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>UTExportedTypeDeclarations</key>
    <array><dict>
        <key>UTTypeIdentifier</key><string>nl.commissiewijzer.app.work</string>
        <key>UTTypeDescription</key><string>CommissieWijzer work document</string>
        <key>UTTypeConformsTo</key><array><string>public.data</string></array>
        <key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>spdfwork</string></array></dict>
    </dict></array>
</dict>
</plist>
PLIST

cp -X AppStore/PrivacyInfo.xcprivacy "$APP_DIR/Contents/Resources/PrivacyInfo.xcprivacy"
cp -X AppStore/Privacy.md "$APP_DIR/Contents/Resources/Privacy.md"

LICENSE_FILES=("$PROJECT_DIR"/ThirdPartyLicenses/*.txt)
test -f "${LICENSE_FILES[0]}"
mkdir -p "$APP_DIR/Contents/Resources/ThirdPartyLicenses"
cp -R -X ThirdPartyLicenses/. "$APP_DIR/Contents/Resources/ThirdPartyLicenses/"
cp -X LICENSE "$APP_DIR/Contents/Resources/ThirdPartyLicenses/CommissieWijzer-MIT.txt"

ICONSET="$PROJECT_DIR/.build/CommissieWijzer.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Assets/CommissieWijzer.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    retina=$((size * 2))
    sips -z "$retina" "$retina" Assets/CommissieWijzer.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/CommissieWijzer.icns"
ICONSET_CATALOG="$PROJECT_DIR/.build/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ICONSET_CATALOG"
cp -X "$ICONSET"/*.png "$ICONSET_CATALOG/"
python3 scripts/icon-catalog.py "$ICONSET_CATALOG"
xcrun actool --compile "$APP_DIR/Contents/Resources" --platform macosx \
    --minimum-deployment-target 14.0 --app-icon AppIcon \
    --output-partial-info-plist "$PROJECT_DIR/.build/icon-info.plist" "$PROJECT_DIR/.build/Assets.xcassets" >/dev/null
python3 - "$APP_DIR/Contents/Info.plist" "$PROJECT_DIR/.build/icon-info.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as stream:
    info = plistlib.load(stream)
with open(sys.argv[2], "rb") as stream:
    info.update(plistlib.load(stream))
# Use the source-derived ICNS as the canonical bundle selector, retaining the
# compiled AppIcon catalog and its 1024-pixel image for store artwork extraction.
info["CFBundleIconFile"] = "CommissieWijzer"
for key in ("CFBundleIconName", "CFBundleIcons", "CFBundleIcons~mac"):
    info.pop(key, None)
with open(sys.argv[1], "wb") as stream:
    plistlib.dump(info, stream)
PY

plutil -lint "$APP_DIR/Contents/Info.plist" "$APP_DIR/Contents/Resources/PrivacyInfo.xcprivacy"
if [[ "$MODE" == store ]]; then
    mkdir -p "$APP_DIR/Contents"
    ditto --rsrc --extattr "$COMMISSIEWIJZER_PROVISION_PROFILE" "$APP_DIR/Contents/embedded.provisionprofile"
    # Remove quarantine only from the copied build artifact, never from the input profile.
    if xattr -p com.apple.quarantine "$APP_DIR/Contents/embedded.provisionprofile" >/dev/null 2>&1; then
        xattr -d com.apple.quarantine "$APP_DIR/Contents/embedded.provisionprofile"
    fi
    codesign --force --options runtime --timestamp --sign "$COMMISSIEWIJZER_APP_SIGN_IDENTITY" \
        --entitlements "$PROJECT_DIR/.build/Store.entitlements" "$APP_DIR"
else
    codesign --force --sign - --entitlements AppStore/CommissieWijzer.entitlements "$APP_DIR"
fi
codesign --verify --strict "$APP_DIR"
python3 scripts/audit-release.py "$APP_DIR" --mode "$MODE"
if [[ "$MODE" == store ]]; then
    PKG="$PROJECT_DIR/dist/CommissieWijzer-1.1.2.pkg"
    productbuild --component "$APP_DIR" /Applications --sign "$COMMISSIEWIJZER_INSTALLER_SIGN_IDENTITY" "$PKG"
    pkgutil --check-signature "$PKG"
    printf 'Store package created; App Store Connect listing, screenshots, and final submission review are separate steps.\n'
fi
printf '\nBuilt %s: %s\n' "$MODE" "$APP_DIR"
