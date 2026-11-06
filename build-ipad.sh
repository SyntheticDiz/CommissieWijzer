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
    project_dir="$(pwd -P)"
    home_dir="$(cd "$HOME" && pwd -P)"
    archive_path="${CW_IPAD_ARCHIVE_PATH:-dist/CommissieWijzer-iPad.xcarchive}"
    mkdir -p "$(dirname "$archive_path")"

    # Keep source paths out of the shipped executable/debug metadata without
    # writing machine-specific paths into the generated Xcode project.
    swift_prefix_flags='$(inherited)'
    swift_prefix_flags+=" -file-prefix-map \"$project_dir=/CommissieWijzer\""
    swift_prefix_flags+=" -file-prefix-map \"$home_dir=/Developer\""
    clang_prefix_flags='$(inherited)'
    clang_prefix_flags+=" -ffile-prefix-map=\"$project_dir=/CommissieWijzer\""
    clang_prefix_flags+=" -ffile-prefix-map=\"$home_dir=/Developer\""

    signing_args=(CODE_SIGN_STYLE=Automatic)
    if [[ -n "${CW_IPAD_PROVISIONING_PROFILE:-}" ]]; then
      signing_args=(CODE_SIGN_STYLE=Manual 'CODE_SIGN_IDENTITY=Apple Distribution'
        "PROVISIONING_PROFILE_SPECIFIER=$CW_IPAD_PROVISIONING_PROFILE")
    fi
    xcodebuild -project iPadOS/CommissieWijzer.xcodeproj -scheme CommissieWijzer-iPad \
      -configuration Release -destination 'generic/platform=iOS' \
      -archivePath "$archive_path" DEVELOPMENT_TEAM="$CW_DEVELOPMENT_TEAM" \
      "OTHER_SWIFT_FLAGS=$swift_prefix_flags" \
      "OTHER_CFLAGS=$clang_prefix_flags" \
      "OTHER_CPLUSPLUSFLAGS=$clang_prefix_flags" \
      ENABLE_TESTABILITY=NO \
      DEPLOYMENT_POSTPROCESSING=YES STRIP_INSTALLED_PRODUCT=YES \
      STRIP_STYLE=debugging COPY_PHASE_STRIP=YES \
      "${signing_args[@]}" archive
    ;;
  *) echo 'Usage: bash build-ipad.sh [simulator|device|archive]' >&2; exit 2 ;;
esac
