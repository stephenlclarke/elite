"""Guard the trust and version boundaries of Homebrew distribution metadata."""

import copy
import unittest

from homebrew_cask import existing_release, render_cask


class HomebrewCaskTests(unittest.TestCase):
    def setUp(self):
        self.revision = "a" * 40
        self.manifest = {
            "appVersion": "1.3.1", "archive": "Elite-1.3.1-universal.zip",
            "sha256": "b" * 64, "minimumMacOS": "14.0",
            "architectures": ["arm64", "x86_64"],
            "signature": "Developer ID Application", "notarized": True,
            "gatekeeperAccepted": True, "hardenedRuntime": True, "secureTimestamp": True,
        }

    def test_cask_pins_asset_commit_and_checksum_without_disabling_quarantine(self):
        cask = render_cask(self.manifest, self.revision)
        self.assertEqual(existing_release(cask), ("1.3.1", self.revision))
        self.assertIn('sha256 "' + "b" * 64 + '"', cask)
        self.assertIn("/" + self.revision + "/releases/macos/", cask)
        self.assertIn("depends_on macos: :sonoma", cask)
        for forbidden in ("no_quarantine", "zap", "preflight", "postflight", "uninstall"):
            self.assertNotIn(forbidden, cask)

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


if __name__ == "__main__":
    unittest.main()
