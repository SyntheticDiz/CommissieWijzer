"""Validate the external App Store profile and derive signed app entitlements."""
import datetime
import plistlib
import subprocess
import sys
from pathlib import Path

BUNDLE_ID = "nl.commissiewijzer.app"


def fail(message: str) -> None:
    raise SystemExit(message)


def main() -> None:
    if len(sys.argv) != 4:
        fail("Usage: store-entitlements.py PROFILE TEAM_ID OUTPUT")
    profile_path, expected_team, output_path = sys.argv[1], sys.argv[2], sys.argv[3]
    try:
        decoded = subprocess.check_output(
            ["security", "cms", "-D", "-i", profile_path], stderr=subprocess.DEVNULL
        )
        profile = plistlib.loads(decoded)
    except (OSError, subprocess.CalledProcessError, plistlib.InvalidFileException) as error:
        fail(f"Could not decode the App Store provisioning profile: {error}")

    teams = profile.get("TeamIdentifier", [])
    if expected_team not in teams:
        fail("The provisioning profile team does not match COMMISSIEWIJZER_TEAM_ID.")
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, datetime.datetime):
        fail("The provisioning profile has no valid expiration date.")
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=datetime.timezone.utc)
    if expiry <= datetime.datetime.now(datetime.timezone.utc):
        fail("The provisioning profile has expired.")
    if profile.get("ProvisionedDevices") or profile.get("ProvisionsAllDevices"):
        fail("Use a Mac App Store distribution profile, not development or ad hoc distribution.")

    profile_entitlements = profile.get("Entitlements", {})
    app_identifier = profile_entitlements.get(
        "com.apple.application-identifier",
        profile_entitlements.get("application-identifier", ""),
    )
    if app_identifier != f"{expected_team}.{BUNDLE_ID}":
        fail("The provisioning profile must target the CommissieWijzer app identifier and team.")
    if profile_entitlements.get("com.apple.developer.team-identifier") != expected_team:
        fail("The provisioning profile team entitlement does not match COMMISSIEWIJZER_TEAM_ID.")
    if profile_entitlements.get("get-task-allow") or profile_entitlements.get("com.apple.security.get-task-allow"):
        fail("A distribution profile must not enable debugging.")

    project_root = Path(__file__).resolve().parents[1]
    try:
        with (project_root / "AppStore" / "CommissieWijzer.entitlements").open("rb") as stream:
            result = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException) as error:
        fail(f"Could not read CommissieWijzer's base entitlements: {error}")
    result["com.apple.application-identifier"] = app_identifier
    result["com.apple.developer.team-identifier"] = expected_team
    # Keep profile-authorized keychain groups, when present, so sandboxed
    # Keychain use remains scoped to this app's distribution identity.
    if "keychain-access-groups" in profile_entitlements:
        result["keychain-access-groups"] = profile_entitlements["keychain-access-groups"]
    Path(output_path).write_bytes(plistlib.dumps(result, sort_keys=True))
    print("Provisioning profile identity, team, expiry, and distribution type validated.")


if __name__ == "__main__":
    main()
