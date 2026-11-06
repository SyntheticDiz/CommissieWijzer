"""Validate a Store profile and derive least-privilege app entitlements."""
import datetime
import plistlib
import subprocess
import sys
from pathlib import Path

BUNDLE_ID = "nl.commissiewijzer.app"
CONTAINER_ID = "iCloud.nl.commissiewijzer.app"
ICLOUD_KEYS = (
    "com.apple.developer.icloud-container-identifiers",
    "com.apple.developer.icloud-services",
    "com.apple.developer.icloud-container-environment",
)


def fail(message: str) -> None:
    raise SystemExit(message)


def decode_profile(path: str) -> dict:
    try:
        decoded = subprocess.check_output(
            ["security", "cms", "-D", "-i", path], stderr=subprocess.DEVNULL
        )
        return plistlib.loads(decoded)
    except (OSError, subprocess.CalledProcessError, plistlib.InvalidFileException) as error:
        fail(f"Could not decode the provisioning profile: {error}")


def validate_identity(profile: dict, expected_team: str, allow_development: bool = False) -> dict:
    teams = profile.get("TeamIdentifier", [])
    if not isinstance(teams, list) or any(not isinstance(team, str) for team in teams):
        fail("The provisioning profile has an invalid team identifier list.")
    if expected_team not in teams:
        fail("The provisioning profile team does not match the configured Apple Developer Team ID.")
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, datetime.datetime):
        fail("The provisioning profile has no valid expiration date.")
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=datetime.timezone.utc)
    if expiry <= datetime.datetime.now(datetime.timezone.utc):
        fail("The provisioning profile has expired.")
    entitlements = profile.get("Entitlements", {})
    if not isinstance(entitlements, dict):
        fail("The provisioning profile has invalid entitlements.")
    devices = profile.get("ProvisionedDevices", [])
    if not isinstance(devices, list) or any(not isinstance(device, str) for device in devices):
        fail("The provisioning profile has an invalid registered-device list.")
    is_development = bool(devices)
    if profile.get("ProvisionsAllDevices") or (is_development and not allow_development):
        fail("Use an App Store distribution profile, not development or ad hoc distribution.")
    if allow_development and not is_development:
        fail("A CloudKit Development environment requires a development provisioning profile with registered devices.")
    app_identifier = entitlements.get(
        "com.apple.application-identifier", entitlements.get("application-identifier", "")
    )
    if app_identifier != f"{expected_team}.{BUNDLE_ID}":
        fail("The provisioning profile must target nl.commissiewijzer.app and the configured team.")
    if entitlements.get("com.apple.developer.team-identifier") != expected_team:
        fail("The provisioning profile team entitlement does not match the configured team.")
    if not allow_development and (entitlements.get("get-task-allow") or entitlements.get("com.apple.security.get-task-allow")):
        fail("A distribution profile must not enable debugging.")
    return entitlements


def validate_icloud(profile_entitlements: dict, expected_environment: str) -> dict:
    if expected_environment not in {"Development", "Production"}:
        fail("CW_ICLOUD_ENVIRONMENT must be Development or Production.")
    containers = profile_entitlements.get(ICLOUD_KEYS[0], [])
    services = profile_entitlements.get(ICLOUD_KEYS[1], [])
    environment = profile_entitlements.get(ICLOUD_KEYS[2])
    if not isinstance(containers, list) or any(not isinstance(item, str) for item in containers):
        fail("The profile has an invalid iCloud container entitlement; expected a list of container identifiers.")
    if CONTAINER_ID not in containers:
        fail(f"The profile does not authorize {CONTAINER_ID}. Enable the iCloud capability and container for this app ID, then regenerate the profile.")
    if isinstance(services, str):
        authorized_services = {services}
    elif isinstance(services, list) and all(isinstance(item, str) for item in services):
        authorized_services = set(services)
    else:
        fail("The profile has an invalid iCloud services entitlement; expected a service name, wildcard, or list of strings.")
    if not authorized_services.intersection({"CloudKit", "*"}):
        fail("The profile does not authorize the iCloud CloudKit service. Enable CloudKit for this app ID and regenerate the profile.")
    if isinstance(environment, str):
        authorized_environments = {environment}
    elif isinstance(environment, list) and all(isinstance(item, str) for item in environment):
        authorized_environments = set(environment)
    else:
        fail("The profile has an invalid iCloud environment entitlement; expected Development, Production, or a list of them.")
    if not authorized_environments or not authorized_environments.issubset({"Development", "Production"}):
        fail("The profile does not authorize a recognized CloudKit environment. Enable iCloud CloudKit and regenerate the profile.")
    if expected_environment not in authorized_environments:
        fail(f"The profile does not authorize the requested CloudKit {expected_environment} environment. Use a matching profile or environment.")
    return {
        ICLOUD_KEYS[0]: [CONTAINER_ID],
        ICLOUD_KEYS[1]: ["CloudKit"],
        ICLOUD_KEYS[2]: expected_environment,
    }


def validate_cloud_profile(profile: dict, expected_team: str, expected_environment: str,
                           allow_development: bool = False,
                           allow_registered_production: bool = False) -> tuple[dict, dict]:
    if expected_environment == "Development" and not allow_development:
        fail("The CloudKit Development environment requires --allow-development and a development provisioning profile.")
    if allow_development and expected_environment != "Development":
        fail("--allow-development can only validate the CloudKit Development environment.")
    if allow_registered_production and expected_environment != "Production":
        fail("--allow-registered-production can only validate the CloudKit Production environment.")
    if allow_development and allow_registered_production:
        fail("Choose either --allow-development or --allow-registered-production.")
    profile_entitlements = validate_identity(profile, expected_team, allow_development or allow_registered_production)
    cloud_entitlements = validate_icloud(profile_entitlements, expected_environment)
    return profile_entitlements, cloud_entitlements


def main() -> None:
    if len(sys.argv) < 4:
        fail("Usage: store-entitlements.py PROFILE TEAM_ID OUTPUT [--icloud Development|Production [--allow-development|--allow-registered-production] [--ios]]")
    args = sys.argv[4:]
    if args and (len(args) < 2 or args[0] != "--icloud"
                 or not set(args[2:]).issubset({"--allow-development", "--allow-registered-production", "--ios"})
                 or len(set(args[2:])) != len(args[2:])):
        fail("Usage: store-entitlements.py PROFILE TEAM_ID OUTPUT [--icloud Development|Production [--allow-development] [--ios]]")
    profile_path, expected_team, output_path = sys.argv[1:4]
    cloud_environment = args[1] if args else None
    allow_development = "--allow-development" in args
    allow_registered_production = "--allow-registered-production" in args
    ios_output = "--ios" in args
    profile = decode_profile(profile_path)
    cloud_result = None
    if cloud_environment:
        profile_entitlements, cloud_result = validate_cloud_profile(
            profile, expected_team, cloud_environment, allow_development, allow_registered_production
        )
    else:
        if allow_development:
            fail("--allow-development requires --icloud Development.")
        if allow_registered_production:
            fail("--allow-registered-production requires --icloud Production.")
        profile_entitlements = validate_identity(profile, expected_team)

    project_root = Path(__file__).resolve().parents[1]
    try:
        with (project_root / "AppStore" / "CommissieWijzer.entitlements").open("rb") as stream:
            result = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException) as error:
        fail(f"Could not read CommissieWijzer's base entitlements: {error}")
    result["com.apple.application-identifier"] = f"{expected_team}.{BUNDLE_ID}"
    result["com.apple.developer.team-identifier"] = expected_team
    if "keychain-access-groups" in profile_entitlements:
        own_group = f"{expected_team}.{BUNDLE_ID}"
        if own_group in profile_entitlements["keychain-access-groups"]:
            result["keychain-access-groups"] = [own_group]
    if cloud_result:
        if ios_output:
            result = cloud_result
        else:
            result.update(cloud_result)
    if allow_development and profile_entitlements.get("get-task-allow") is True:
        result["com.apple.security.get-task-allow"] = True
    Path(output_path).write_bytes(plistlib.dumps(result, sort_keys=True))
    print("Provisioning profile identity, team, expiry, and distribution type validated.")
    if cloud_environment:
        print(f"Profile-authorized CloudKit access validated for {CONTAINER_ID} ({cloud_environment}).")


if __name__ == "__main__":
    main()
