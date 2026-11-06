"""Offline fixtures for profile authorization and least-privilege CloudKit access."""
import importlib.util
import plistlib
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "store-entitlements.py"
ROOT = MODULE_PATH.parents[1]
SPEC = importlib.util.spec_from_file_location("store_entitlements", MODULE_PATH)
assert SPEC and SPEC.loader
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


def cloud_profile(**overrides):
    result = {
        "com.apple.developer.icloud-container-identifiers": [module.CONTAINER_ID],
        "com.apple.developer.icloud-services": ["CloudKit"],
        "com.apple.developer.icloud-container-environment": "Production",
    }
    result.update(overrides)
    return result


class CloudKitProfileTests(unittest.TestCase):
    def test_default_preview_entitlements_do_not_enable_icloud_or_push(self):
        with (ROOT / "AppStore" / "CommissieWijzer.entitlements").open("rb") as stream:
            preview = plistlib.load(stream)
        self.assertFalse(any(key.startswith("com.apple.developer.icloud-") or key == "aps-environment"
                             for key in preview))
        project = (ROOT / "iPadOS" / "CommissieWijzer.xcodeproj" / "project.pbxproj").read_text()
        self.assertIn('CW_CLOUDKIT_ENABLED = "NO"', project)
        self.assertIn('CW_CLOUDKIT_ENVIRONMENT = "Disabled"', project)
        with (ROOT / "iPadOS" / "Info.plist").open("rb") as stream:
            info = plistlib.load(stream)
        self.assertEqual(info["CWCloudKitEnabled"], "$(CW_CLOUDKIT_ENABLED)")
        self.assertEqual(info["CWCloudKitEnvironment"], "$(CW_CLOUDKIT_ENVIRONMENT)")

    def test_cloud_enabled_distribution_profile_yields_only_requested_cloudkit_values(self):
        entitlements = module.validate_icloud(cloud_profile(), "Production")
        self.assertEqual(entitlements, {
            "com.apple.developer.icloud-container-identifiers": [module.CONTAINER_ID],
            "com.apple.developer.icloud-services": ["CloudKit"],
            "com.apple.developer.icloud-container-environment": "Production",
        })

    def test_missing_container_is_rejected_with_setup_guidance(self):
        with self.assertRaisesRegex(SystemExit, "does not authorize iCloud.nl.commissiewijzer.app"):
            module.validate_icloud(cloud_profile(**{
                "com.apple.developer.icloud-container-identifiers": []
            }), "Production")

    def test_missing_cloudkit_service_is_rejected(self):
        with self.assertRaisesRegex(SystemExit, "does not authorize the iCloud CloudKit service"):
            module.validate_icloud(cloud_profile(**{
                "com.apple.developer.icloud-services": ["CloudDocuments"]
            }), "Production")

    def test_environment_must_match_the_profile(self):
        with self.assertRaisesRegex(SystemExit, "does not authorize the requested CloudKit Development environment"):
            module.validate_icloud(cloud_profile(), "Development")

    def test_actual_apple_profile_wildcard_and_environment_array_are_authorized_narrowly(self):
        actual_shape = cloud_profile(**{
            "com.apple.developer.icloud-services": "*",
            "com.apple.developer.icloud-container-environment": ["Production", "Development"],
            "com.apple.developer.icloud-development-container-identifiers": [module.CONTAINER_ID],
        })
        for environment in ("Production", "Development"):
            entitlements = module.validate_icloud(actual_shape, environment)
            self.assertEqual(entitlements["com.apple.developer.icloud-services"], ["CloudKit"])
            self.assertEqual(entitlements["com.apple.developer.icloud-container-identifiers"], [module.CONTAINER_ID])
            self.assertEqual(entitlements["com.apple.developer.icloud-container-environment"], environment)

    def test_service_list_with_cloudkit_is_supported(self):
        profile = cloud_profile(**{
            "com.apple.developer.icloud-services": ["CloudDocuments", "CloudKit"]
        })
        self.assertEqual(module.validate_icloud(profile, "Production")[
            "com.apple.developer.icloud-services"], ["CloudKit"])

    def test_development_environment_is_only_authorized_by_development_profile(self):
        team = "TEAMFIXTURE"
        entitlements = {
            "application-identifier": f"{team}.{module.BUNDLE_ID}",
            "com.apple.developer.team-identifier": team,
            **cloud_profile(**{
                "com.apple.developer.icloud-container-environment": ["Production", "Development"]
            }),
        }
        distribution_profile = {
            "TeamIdentifier": [team],
            "ExpirationDate": datetime.now(timezone.utc) + timedelta(days=1),
            "Entitlements": entitlements,
        }
        with self.assertRaisesRegex(SystemExit, "requires --allow-development"):
            module.validate_cloud_profile(distribution_profile, team, "Development")
        with self.assertRaisesRegex(SystemExit, "requires a development provisioning profile"):
            module.validate_cloud_profile(distribution_profile, team, "Development", allow_development=True)

        developer_profile = {
            **distribution_profile,
            "ProvisionedDevices": ["FIXTURE-DEVICE"],
        }
        validated_profile, validated_app_entitlements = module.validate_cloud_profile(
            developer_profile, team, "Development", allow_development=True
        )
        self.assertEqual(validated_profile, entitlements)
        self.assertEqual(validated_app_entitlements["com.apple.developer.icloud-container-environment"], "Development")

    def test_registered_profile_can_opt_into_production_only_for_local_signed_builds(self):
        team = "TEAMFIXTURE"
        profile_entitlements = {
            "application-identifier": f"{team}.{module.BUNDLE_ID}",
            "com.apple.developer.team-identifier": team,
            **cloud_profile(**{
                "com.apple.developer.icloud-container-environment": ["Production", "Development"]
            }),
        }
        profile = {
            "TeamIdentifier": [team],
            "ProvisionedDevices": ["FIXTURE-MAC"],
            "ExpirationDate": datetime.now(timezone.utc) + timedelta(days=1),
            "Entitlements": profile_entitlements,
        }
        with self.assertRaisesRegex(SystemExit, "distribution profile"):
            module.validate_cloud_profile(profile, team, "Production")
        _, production_entitlements = module.validate_cloud_profile(
            profile, team, "Production", allow_registered_production=True
        )
        self.assertEqual(production_entitlements["com.apple.developer.icloud-container-environment"], "Production")

    def test_malformed_or_unsupported_authorization_values_are_rejected(self):
        with self.assertRaisesRegex(SystemExit, "invalid iCloud container entitlement"):
            module.validate_icloud(cloud_profile(**{
                "com.apple.developer.icloud-container-identifiers": module.CONTAINER_ID
            }), "Production")
        with self.assertRaisesRegex(SystemExit, "invalid iCloud services entitlement"):
            module.validate_icloud(cloud_profile(**{
                "com.apple.developer.icloud-services": {"CloudKit": True}
            }), "Production")
        with self.assertRaisesRegex(SystemExit, "invalid iCloud environment entitlement"):
            module.validate_icloud(cloud_profile(**{
                "com.apple.developer.icloud-container-environment": ["Production", 3]
            }), "Production")
        with self.assertRaisesRegex(SystemExit, "does not authorize a recognized CloudKit environment"):
            module.validate_icloud(cloud_profile(**{
                "com.apple.developer.icloud-container-environment": ["Staging"]
            }), "Production")
        with self.assertRaisesRegex(SystemExit, "does not authorize the requested CloudKit Development environment"):
            module.validate_icloud(cloud_profile(**{
                "com.apple.developer.icloud-container-environment": ["Production"]
            }), "Development")

    def test_expired_profiles_are_rejected(self):
        with self.assertRaisesRegex(SystemExit, "profile has expired"):
            module.validate_identity({
                "TeamIdentifier": ["TEAMFIXTURE"],
                "ExpirationDate": datetime.now(timezone.utc) - timedelta(days=1),
                "Entitlements": {},
            }, "TEAMFIXTURE")

    def test_wrong_identity_profile_is_rejected(self):
        team = "TEAMFIXTURE"
        profile = {
            "TeamIdentifier": [team],
            "ExpirationDate": datetime.now(timezone.utc) + timedelta(days=1),
            "Entitlements": {
                "application-identifier": f"{team}.{module.BUNDLE_ID}",
                "com.apple.developer.team-identifier": team,
            },
        }
        module.validate_identity(profile, team)
        profile["Entitlements"]["application-identifier"] = f"{team}.wrong.bundle"
        with self.assertRaisesRegex(SystemExit, "must target nl.commissiewijzer.app"):
            module.validate_identity(profile, team)

    def test_development_profile_is_only_accepted_for_explicit_development_validation(self):
        team = "TEAMFIXTURE"
        profile = {
            "TeamIdentifier": [team],
            "ProvisionedDevices": ["FIXTURE-DEVICE"],
            "ExpirationDate": datetime.now(timezone.utc) + timedelta(days=1),
            "Entitlements": {
                "application-identifier": f"{team}.{module.BUNDLE_ID}",
                "com.apple.developer.team-identifier": team,
                "get-task-allow": True,
            },
        }
        with self.assertRaisesRegex(SystemExit, "distribution profile"):
            module.validate_identity(profile, team)
        self.assertEqual(module.validate_identity(profile, team, allow_development=True),
                         profile["Entitlements"])


if __name__ == "__main__":
    unittest.main()
