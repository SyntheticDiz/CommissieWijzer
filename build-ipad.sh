#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
PROJECT_DIR="$(pwd -P)"
BUILD_CACHE_ROOT="$PROJECT_DIR/.build/ipad-release-cache"
export TMPDIR="$BUILD_CACHE_ROOT/tmp"
export CLANG_MODULE_CACHE_PATH="$BUILD_CACHE_ROOT/modules"
export SWIFT_MODULECACHE_PATH="$BUILD_CACHE_ROOT/modules"
export XDG_CACHE_HOME="$BUILD_CACHE_ROOT/xdg"
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$TMPDIR" "$CLANG_MODULE_CACHE_PATH" "$XDG_CACHE_HOME"
python3 scripts/generate-ipad-project.py
mode="${1:-simulator}"
derived_data="${CW_IPAD_DERIVED_DATA:-.build/ipad}"
CW_ENABLE_ICLOUD="${CW_ENABLE_ICLOUD:-0}"
if [[ "$CW_ENABLE_ICLOUD" != 0 && "$CW_ENABLE_ICLOUD" != 1 ]]; then
  echo 'Set CW_ENABLE_ICLOUD to 0 or 1.' >&2
  exit 2
fi
if [[ "$CW_ENABLE_ICLOUD" == 1 && "$mode" != archive ]]; then
  echo 'CloudKit requires an archive signed with a validated Development or Production profile.' >&2
  exit 2
fi
if [[ "$mode" == archive && "$CW_ENABLE_ICLOUD" != 1 ]]; then
  echo 'A 1.3.0 iPad distribution archive must include CloudKit. Set CW_ENABLE_ICLOUD=1 and provide a matching profile.' >&2
  exit 2
fi
cloud_entitlements=()
cloud_build_settings=()
cloud_profile_uuid=""
prepare_icloud_entitlements() {
  CW_ICLOUD_ENVIRONMENT="${CW_ICLOUD_ENVIRONMENT:-Production}"
  local environment="$CW_ICLOUD_ENVIRONMENT"
  local profile="${CW_IPAD_ICLOUD_PROFILE:-}"
  : "${CW_DEVELOPMENT_TEAM:?Set CW_DEVELOPMENT_TEAM to your Apple Developer team ID for a CloudKit build}"
  : "${profile:?Set CW_IPAD_ICLOUD_PROFILE to the matching iCloud-enabled provisioning profile file}"
  local profile_args=(--icloud "$environment" --ios)
  if [[ "$environment" == Development ]]; then
    profile_args+=(--allow-development)
  elif [[ "$environment" != Production ]]; then
    echo 'CW_ICLOUD_ENVIRONMENT must be Development or Production.' >&2
    exit 2
  fi
  local entitlements="$(pwd -P)/.build/ipad-icloud-entitlements.plist"
  mkdir -p "$(dirname "$entitlements")"
  python3 scripts/store-entitlements.py "$profile" "$CW_DEVELOPMENT_TEAM" "$entitlements" "${profile_args[@]}"
  cloud_profile_uuid="$(security cms -D -i "$profile" | python3 -c 'import plistlib,sys; print(plistlib.loads(sys.stdin.buffer.read()).get("UUID", ""))')"
  if [[ -z "$cloud_profile_uuid" ]]; then
    echo 'The validated iCloud provisioning profile has no UUID.' >&2
    exit 1
  fi
  cloud_entitlements=("CODE_SIGN_ENTITLEMENTS=$entitlements")
  cloud_build_settings=(CW_CLOUDKIT_ENABLED=YES "CW_CLOUDKIT_ENVIRONMENT=$environment")
}
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
    if [[ "$CW_ENABLE_ICLOUD" == 1 ]]; then
      prepare_icloud_entitlements
    fi
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
    if [[ -n "$cloud_profile_uuid" ]]; then
      if [[ "$CW_ICLOUD_ENVIRONMENT" == Development ]]; then
        signing_args=(CODE_SIGN_STYLE=Manual 'CODE_SIGN_IDENTITY=Apple Development'
          "PROVISIONING_PROFILE_SPECIFIER=$cloud_profile_uuid")
      else
        signing_args=(CODE_SIGN_STYLE=Manual 'CODE_SIGN_IDENTITY=Apple Distribution'
          "PROVISIONING_PROFILE_SPECIFIER=$cloud_profile_uuid")
      fi
    fi
    xcodebuild -project iPadOS/CommissieWijzer.xcodeproj -scheme CommissieWijzer-iPad \
      -configuration Release -destination 'generic/platform=iOS' \
      -archivePath "$archive_path" -derivedDataPath "$derived_data" DEVELOPMENT_TEAM="$CW_DEVELOPMENT_TEAM" \
      "OTHER_SWIFT_FLAGS=$swift_prefix_flags" \
      "OTHER_CFLAGS=$clang_prefix_flags" \
      "OTHER_CPLUSPLUSFLAGS=$clang_prefix_flags" \
      ENABLE_TESTABILITY=NO \
      DEPLOYMENT_POSTPROCESSING=YES STRIP_INSTALLED_PRODUCT=YES \
      STRIP_STYLE=debugging COPY_PHASE_STRIP=YES \
      "${cloud_entitlements[@]}" "${cloud_build_settings[@]}" \
      "${signing_args[@]}" archive
    ;;
  *) echo 'Usage: bash build-ipad.sh [simulator|device|archive]' >&2; exit 2 ;;
esac
