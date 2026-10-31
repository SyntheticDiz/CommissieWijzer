#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 scripts/generate-ipad-project.py
mode="${1:-simulator}"
derived_data="${CW_IPAD_DERIVED_DATA:-.build/ipad}"
case "$mode" in
  simulator)
    : "${CW_DEVELOPMENT_TEAM:?Set CW_DEVELOPMENT_TEAM to your Apple Developer team ID for a simulator build with working Keychain access}"
    xcodebuild -project iPadOS/CommissieWijzer.xcodeproj -scheme CommissieWijzer-iPad \
      -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$derived_data" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- \
      DEVELOPMENT_TEAM="$CW_DEVELOPMENT_TEAM" build
    ;;
  device)
    xcodebuild -project iPadOS/CommissieWijzer.xcodeproj -scheme CommissieWijzer-iPad \
      -configuration Release -destination 'generic/platform=iOS' -derivedDataPath .build/ipad-device \
      CODE_SIGNING_ALLOWED=NO build
    ;;
  archive)
    : "${CW_DEVELOPMENT_TEAM:?Set CW_DEVELOPMENT_TEAM to your Apple Developer team ID}"
    signing_args=(CODE_SIGN_STYLE=Automatic)
    if [[ -n "${CW_IPAD_PROVISIONING_PROFILE:-}" ]]; then
      signing_args=(CODE_SIGN_STYLE=Manual 'CODE_SIGN_IDENTITY=Apple Distribution'
        "PROVISIONING_PROFILE_SPECIFIER=$CW_IPAD_PROVISIONING_PROFILE")
    fi
    xcodebuild -project iPadOS/CommissieWijzer.xcodeproj -scheme CommissieWijzer-iPad \
      -configuration Release -destination 'generic/platform=iOS' \
      -archivePath dist/CommissieWijzer-iPad.xcarchive DEVELOPMENT_TEAM="$CW_DEVELOPMENT_TEAM" \
      "${signing_args[@]}" archive
    ;;
  *) echo 'Usage: bash build-ipad.sh [simulator|device|archive]' >&2; exit 2 ;;
esac
