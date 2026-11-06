"""Audit the built bundle's identity, sandbox, privacy resources, and path hygiene."""
import argparse
import datetime
import os
import plistlib
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

BUNDLE_ID = "nl.commissiewijzer.app"
ICLOUD_CONTAINER_ID = "iCloud.nl.commissiewijzer.app"
ICLOUD_ENVIRONMENTS = {"Development", "Production"}
VERSION = "1.2.0"
BUILD = "8"
MINIMUM_SYSTEM = "14.0"


def attributes(path: Path) -> list[str]:
    try:
        return os.listxattr(path, follow_symlinks=False)
    except AttributeError:
        result = subprocess.run(["xattr", "-s", str(path)], capture_output=True, text=True)
        if result.returncode:
            raise OSError(result.stderr.strip() or "xattr inspection failed")
        return result.stdout.splitlines()


def read_plist(path: Path):
    with path.open("rb") as stream:
        return plistlib.load(stream)


def fail_if(failures: list[str], condition: bool, message: str) -> None:
    if condition:
        failures.append(message)


def authorized_string(value, expected: str) -> bool:
    """Check scalar or array profile authorization, including Apple's wildcard."""
    if isinstance(value, str):
        return value in {expected, "*"}
    return (isinstance(value, list) and all(isinstance(item, str) for item in value)
            and (expected in value or "*" in value))


def authorized_environment(value, expected: str) -> bool:
    if isinstance(value, str):
        environments = {value}
    elif isinstance(value, list) and all(isinstance(item, str) for item in value):
        environments = set(value)
    else:
        return False
    return bool(environments) and environments.issubset(ICLOUD_ENVIRONMENTS) and expected in environments


def valid_environment_authorization(value) -> bool:
    if isinstance(value, str):
        environments = {value}
    elif isinstance(value, list) and all(isinstance(item, str) for item in value):
        environments = set(value)
    else:
        return False
    return bool(environments) and environments.issubset(ICLOUD_ENVIRONMENTS)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("app", type=Path)
    parser.add_argument("--mode", choices=("preview", "development", "local-production", "store"), required=True)
    parser.add_argument("--icloud", action="store_true", help="require profile-authorized CloudKit entitlements")
    args = parser.parse_args()
    app = args.app.resolve()
    failures: list[str] = []
    info_path = app / "Contents" / "Info.plist"
    resources = app / "Contents" / "Resources"
    executable = app / "Contents" / "MacOS" / "CommissieWijzer"

    try:
        info = read_plist(info_path)
        privacy = read_plist(resources / "PrivacyInfo.xcprivacy")
    except (OSError, plistlib.InvalidFileException) as error:
        print(f"Could not read required app metadata: {error}", file=sys.stderr)
        return 1

    expected = {
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleExecutable": "CommissieWijzer",
        "CFBundleShortVersionString": VERSION,
        "CFBundleVersion": BUILD,
        "LSMinimumSystemVersion": MINIMUM_SYSTEM,
        "CFBundleIconFile": "CommissieWijzer",
    }
    for key, value in expected.items():
        fail_if(failures, info.get(key) != value, f"Incorrect {key}.")
    cloudkit_enabled = args.icloud and args.mode in {"development", "local-production", "store"}
    fail_if(failures, info.get("CWCloudKitEnabled") is not cloudkit_enabled,
            "CWCloudKitEnabled must match the selected profile-validated build mode.")
    expected_cloud_environment = ("Development" if args.mode == "development" else "Production") if cloudkit_enabled else "Disabled"
    fail_if(failures, info.get("CWCloudKitEnvironment") != expected_cloud_environment,
            f"CWCloudKitEnvironment must be {expected_cloud_environment} for this build.")
    for key in ("CFBundleIconName", "CFBundleIcons", "CFBundleIcons~mac"):
        fail_if(failures, key in info, f"Unexpected alternate bundle icon selector {key}.")
    type_declarations = info.get("UTExportedTypeDeclarations", [])
    matching_type = next(
        (item for item in type_declarations if item.get("UTTypeIdentifier") == "nl.commissiewijzer.app.work"),
        None,
    )
    fail_if(failures, matching_type is None, "CommissieWijzer work document UTI is missing.")
    if matching_type:
        extensions = matching_type.get("UTTypeTagSpecification", {}).get("public.filename-extension", [])
        fail_if(failures, "spdfwork" not in extensions, "The work document type must retain the .spdfwork extension.")

    fail_if(failures, not executable.is_file(), "App executable is missing.")
    fail_if(failures, not (resources / "CommissieWijzer.icns").is_file(), "Canonical CommissieWijzer.icns is missing.")
    catalog = resources / "Assets.car"
    compiled_icon = resources / "AppIcon.icns"
    fail_if(failures, not catalog.is_file(), "Compiled AppIcon asset catalog is missing.")
    fail_if(failures, not compiled_icon.is_file(), "Compiled AppIcon.icns is missing.")
    if catalog.is_file() and compiled_icon.is_file():
        try:
            with tempfile.TemporaryDirectory(prefix="commissiewijzer-icon-audit-") as directory:
                iconset = Path(directory) / "AppIcon.iconset"
                subprocess.run(["iconutil", "-c", "iconset", "-o", str(iconset), str(catalog), "AppIcon"],
                               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                icon = iconset / "icon_512x512@2x.png"
                header = icon.read_bytes()[:24]
                fail_if(failures, len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n"
                        or struct.unpack(">II", header[16:24]) != (1024, 1024),
                        "Compiled AppIcon catalog must retain its 1024 x 1024 store image.")
        except (OSError, subprocess.CalledProcessError) as error:
            failures.append(f"Could not validate the compiled AppIcon catalog image: {error}")
    fail_if(failures, not (resources / "Privacy.md").is_file(), "Bundled Privacy.md is missing.")
    fail_if(failures, not (resources / "ThirdPartyLicenses" / "CommissieWijzer-MIT.txt").is_file(), "MIT license is missing.")
    fail_if(failures, not any((resources / "ThirdPartyLicenses").glob("*.txt")), "Third-party licenses are missing.")

    fail_if(failures, privacy.get("NSPrivacyTracking") is not False, "Privacy manifest must declare no tracking.")
    collected = {
        item.get("NSPrivacyCollectedDataType"): item
        for item in privacy.get("NSPrivacyCollectedDataTypes", [])
    }
    for kind in ("EmailAddress", "UserID", "DeviceID", "OtherUserContent"):
        key = "NSPrivacyCollectedDataType" + kind
        item = collected.get(key)
        fail_if(failures, item is None, f"Privacy manifest is missing {kind} disclosure.")
        if item:
            fail_if(failures, item.get("NSPrivacyCollectedDataTypeTracking") is not False, f"{kind} must not be declared as tracking.")
    api_types = {
        item.get("NSPrivacyAccessedAPIType"): item.get("NSPrivacyAccessedAPITypeReasons", [])
        for item in privacy.get("NSPrivacyAccessedAPITypes", [])
    }
    required_api_reasons = {
        "NSPrivacyAccessedAPICategoryUserDefaults": "CA92.1",
        "NSPrivacyAccessedAPICategorySystemBootTime": "35F9.1",
        "NSPrivacyAccessedAPICategoryFileTimestamp": "C617.1",
    }
    for category, reason in required_api_reasons.items():
        fail_if(failures, reason not in api_types.get(category, []), f"Privacy manifest reason {reason} for {category} is missing.")

    try:
        entitlements_data = subprocess.check_output(
            ["codesign", "-d", "--entitlements", "-", "--xml", str(app)], stderr=subprocess.DEVNULL
        )
        entitlements = plistlib.loads(entitlements_data)
    except (OSError, subprocess.CalledProcessError, plistlib.InvalidFileException) as error:
        print(f"Could not inspect app signature entitlements: {error}", file=sys.stderr)
        return 1
    for key in ("com.apple.security.app-sandbox", "com.apple.security.files.user-selected.read-write",
                "com.apple.security.files.bookmarks.app-scope", "com.apple.security.network.client",
                "com.apple.security.network.server"):
        fail_if(failures, entitlements.get(key) is not True, f"Required sandbox entitlement {key} is missing.")
    if args.mode != "development":
        fail_if(failures, entitlements.get("com.apple.security.get-task-allow") is True,
                "The distribution signature must not enable debugging.")

    profile_path = app / "Contents" / "embedded.provisionprofile"
    if args.mode in {"development", "local-production", "store"}:
        fail_if(failures, not profile_path.is_file(), "Signed app provisioning profile is missing.")
        fail_if(failures, entitlements.get("com.apple.application-identifier") is None,
                "Store application identifier entitlement is missing.")
        fail_if(failures, entitlements.get("com.apple.developer.team-identifier") is None,
                "Store team entitlement is missing.")
        if profile_path.is_file():
            try:
                profile = plistlib.loads(subprocess.check_output(
                    ["security", "cms", "-D", "-i", str(profile_path)], stderr=subprocess.DEVNULL
                ))
                profile_entitlements = profile.get("Entitlements", {})
                app_identifier = entitlements.get("com.apple.application-identifier")
                team = entitlements.get("com.apple.developer.team-identifier")
                fail_if(failures, app_identifier != f"{team}.{BUNDLE_ID}", "Signed app identifier does not match the app bundle and team.")
                fail_if(failures, app_identifier != profile_entitlements.get("com.apple.application-identifier", profile_entitlements.get("application-identifier")),
                        "Signed app identifier does not match the embedded profile.")
                fail_if(failures, team not in profile.get("TeamIdentifier", []), "Signed team does not match the embedded profile.")
                app_cloud_containers = entitlements.get("com.apple.developer.icloud-container-identifiers", [])
                app_cloud_services = entitlements.get("com.apple.developer.icloud-services", [])
                app_cloud_environment = entitlements.get("com.apple.developer.icloud-container-environment")
                profile_cloud_containers = profile_entitlements.get("com.apple.developer.icloud-container-identifiers", [])
                profile_cloud_services = profile_entitlements.get("com.apple.developer.icloud-services", [])
                profile_cloud_environment = profile_entitlements.get("com.apple.developer.icloud-container-environment")
                if args.icloud:
                    fail_if(failures, not isinstance(profile_cloud_containers, list)
                            or any(not isinstance(item, str) for item in profile_cloud_containers)
                            or ICLOUD_CONTAINER_ID not in profile_cloud_containers,
                            f"CloudKit release profile does not authorize {ICLOUD_CONTAINER_ID}; enable the app ID capability and regenerate the profile.")
                    fail_if(failures, not authorized_string(profile_cloud_services, "CloudKit"),
                            "CloudKit release profile does not authorize the CloudKit service; enable it for the app ID and regenerate the profile.")
                    fail_if(failures, not valid_environment_authorization(profile_cloud_environment),
                            "CloudKit release profile has no recognized iCloud environment.")
                    expected_profile_environment = "Development" if args.mode == "development" else "Production"
                    fail_if(failures, not authorized_environment(profile_cloud_environment, expected_profile_environment),
                            f"CloudKit {args.mode} builds must use the {expected_profile_environment} environment.")
                    fail_if(failures, app_cloud_containers != [ICLOUD_CONTAINER_ID]
                            or app_cloud_services != ["CloudKit"]
                            or app_cloud_environment != expected_profile_environment,
                            "Signed CloudKit entitlements do not match the least-privilege profile-authorized container, service, and environment.")
                else:
                    fail_if(failures, bool(app_cloud_containers or app_cloud_services or app_cloud_environment),
                            "CloudKit entitlements are present in a build that did not opt in with CW_ENABLE_ICLOUD=1.")
                if args.mode == "store":
                    fail_if(failures, bool(profile.get("ProvisionedDevices")) or bool(profile.get("ProvisionsAllDevices")),
                            "Embedded profile is not an App Store distribution profile.")
                else:
                    fail_if(failures, not profile.get("ProvisionedDevices") or bool(profile.get("ProvisionsAllDevices")),
                            "Embedded profile is not a registered-device development profile.")
                expiry = profile.get("ExpirationDate")
                if isinstance(expiry, datetime.datetime):
                    if expiry.tzinfo is None:
                        expiry = expiry.replace(tzinfo=datetime.timezone.utc)
                    fail_if(failures, expiry <= datetime.datetime.now(datetime.timezone.utc), "Embedded provisioning profile has expired.")
                else:
                    failures.append("Embedded provisioning profile has no expiration date.")
            except (OSError, subprocess.CalledProcessError, plistlib.InvalidFileException) as error:
                failures.append(f"Could not inspect embedded provisioning profile: {error}")
        if args.mode == "store":
            try:
                architectures = set(subprocess.check_output(["lipo", "-archs", str(executable)], text=True).split())
                fail_if(failures, not {"arm64", "x86_64"}.issubset(architectures), "Store executable must be universal arm64 and x86_64.")
            except (OSError, subprocess.CalledProcessError) as error:
                failures.append(f"Could not inspect store executable architectures: {error}")
    elif args.icloud:
        failures.append("CloudKit entitlements require a profile-validated Development or Store build.")

    for path in (app, *app.rglob("*")):
        try:
            fail_if(failures, "com.apple.quarantine" in attributes(path),
                    "Quarantine attribute remains in bundle at " + ("." if path == app else str(path.relative_to(app))) + ".")
        except OSError as error:
            failures.append(f"Could not inspect bundle attributes: {error}")

    if executable.is_file():
        binary = executable.read_bytes()
        private_roots = {str(Path.home()).encode(), str(Path(__file__).resolve().parents[1]).encode()}
        for private_root in private_roots:
            fail_if(failures, bool(private_root) and private_root in binary,
                    "App executable contains a local home or project path.")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"Release artifact audit passed for {args.mode} mode; this checks the bundle only, not App Store Connect metadata or submission readiness.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
