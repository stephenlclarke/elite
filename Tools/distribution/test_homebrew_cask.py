"""Guard the trust and version boundaries of Homebrew distribution metadata."""

import copy
import hashlib
import io
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import homebrew_cask
import release_version
from homebrew_cask import existing_release, release_url, render_cask


class HomebrewCaskTests(unittest.TestCase):
    def setUp(self):
        self.revision = "a" * 40
        self.manifest = {
            "appVersion": "1.3.1", "archive": "L337-1.3.1-universal.zip",
            "sha256": "b" * 64, "minimumMacOS": "14.0",
            "architectures": ["arm64", "x86_64"],
            "signature": "Developer ID Application", "notarized": True,
            "gatekeeperAccepted": True, "hardenedRuntime": True, "secureTimestamp": True,
        }

    def test_cask_pins_asset_commit_and_checksum_without_disabling_quarantine(self):
        cask = render_cask(self.manifest, self.revision)
        self.assertEqual(existing_release(cask), ("1.3.1", self.revision))
        self.assertIn('sha256 "' + "b" * 64 + '"', cask)
        self.assertIn("# Artifact commit: " + self.revision, cask)
        self.assertIn("github.com/stephenlclarke/l337/releases/download/v#{version}/", cask)
        self.assertEqual(release_url("1.3.1"),
                         "https://github.com/stephenlclarke/l337/releases/download/"
                         "v1.3.1/L337-1.3.1-universal.zip")
        self.assertIn("    url :homepage\n    strategy :github_latest", cask)
        self.assertIn("depends_on macos: :sonoma", cask)
        for forbidden in ("no_quarantine", "zap", "preflight", "postflight", "uninstall"):
            self.assertNotIn(forbidden, cask)

    def test_legacy_cask_can_be_checked_without_changing_its_trusted_download(self):
        legacy = render_cask(self.manifest, self.revision, release_assets=False)
        self.assertEqual(existing_release(legacy), ("1.3.1", self.revision))
        self.assertIn("/" + self.revision + "/releases/macos/", legacy)
        self.assertNotIn("# Artifact commit:", legacy)
        self.assertNotEqual(legacy, render_cask(self.manifest, self.revision))

    def test_unverified_or_incompatible_artifact_is_rejected(self):
        for key, value in (
            ("notarized", False), ("gatekeeperAccepted", False),
            ("hardenedRuntime", False), ("secureTimestamp", False),
            ("signature", "adhoc"), ("architectures", ["arm64"]),
            ("minimumMacOS", "13.0"), ("archive", "wrong.zip"),
            ("appVersion", "latest"), ("sha256", "bad"),
        ):
            with self.subTest(key=key):
                manifest = copy.deepcopy(self.manifest)
                manifest[key] = value
                with self.assertRaises(ValueError):
                    render_cask(manifest, self.revision)
        with self.assertRaises(ValueError):
            render_cask(self.manifest, "main")
        with self.assertRaises(ValueError):
            existing_release('version "latest"')

    def test_new_cask_uses_the_same_public_generated_plan_and_verified_archive(self):
        plan = release_version.make_plan("v1.4.0", "a" * 40, self.revision,
                                         [{"impact": "minor"}], True)
        archive = b"public archive fixture"
        manifest = {**self.manifest, "appVersion": plan["version"],
                    "archive": release_version.artifact_prefix(plan) + ".zip",
                    "sourceRevision": self.revision, "releasePlanSha256": release_version.plan_digest(plan),
                    "archiveBytes": len(archive), "sha256": hashlib.sha256(archive).hexdigest()}
        options = SimpleNamespace(release_plan=Path("plan.json"), check=False, verify_download=False)
        with patch.object(homebrew_cask, "load_plan", return_value=plan), \
             patch.object(homebrew_cask, "public_json", side_effect=[plan, manifest]), \
             patch.object(release_version, "validate_plan", return_value=plan), \
             patch.object(homebrew_cask, "published_plan"), \
             patch.object(homebrew_cask.urllib.request, "urlopen", return_value=io.BytesIO(archive)):
            version, source, cask = homebrew_cask.planned_release(options, Path("unused"))
        self.assertEqual((version, source), (plan["version"], self.revision))
        self.assertIn('# Source commit: ' + self.revision, cask)
        self.assertIn('version "1.5.0"', cask)
        with patch.object(homebrew_cask, "load_plan", return_value=plan), \
             patch.object(homebrew_cask, "public_json", return_value={**plan, "version": "9.0.0"}), \
             self.assertRaisesRegex(ValueError, "differs"):
            homebrew_cask.planned_release(options, Path("unused"))


if __name__ == "__main__":
    unittest.main()
