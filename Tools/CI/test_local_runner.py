"""Check trust rejection and preservation of incremental build data."""

from pathlib import Path
import contextlib
import io
import json
import tempfile
import unittest
from unittest.mock import patch

import local_runner
from local_runner import SWIFT, cache_key, link_build_cache, require_trusted_push


class LocalRunnerTests(unittest.TestCase):
    def test_trusted_push(self):
        require_trusted_push(
            {"GITHUB_EVENT_NAME": "push", "GITHUB_REPOSITORY": "stephenlclarke/elite",
             "GITHUB_ACTOR_ID": "22142777"},
            {"repository": {"full_name": "stephenlclarke/elite", "fork": False}},
        )

    def test_rejects_untrusted_events(self):
        original = {"GITHUB_EVENT_NAME": "push", "GITHUB_REPOSITORY": "stephenlclarke/elite",
                    "GITHUB_ACTOR_ID": "22142777"}
        for key, value in (("GITHUB_EVENT_NAME", "pull_request"),
                           ("GITHUB_EVENT_NAME", "workflow_dispatch"),
                           ("GITHUB_REPOSITORY", "other/elite"),
                           ("GITHUB_ACTOR_ID", "123")):
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                require_trusted_push(dict(original, **{key: value}),
                                     {"repository": {"full_name": "stephenlclarke/elite",
                                                     "fork": False}})
        for repository in ({}, {"full_name": "other/elite", "fork": False},
                           {"full_name": "stephenlclarke/elite", "fork": True}):
            with self.subTest(repository=repository), self.assertRaises(ValueError):
                require_trusted_push(original, {"repository": repository})

    def test_cache_identity_tracks_build_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Package.swift").write_text("first")
            first = cache_key(root, "swift-a", "15.5")
            self.assertEqual(first, cache_key(root, "swift-a", "15.5"))
            self.assertNotEqual(first, cache_key(root, "swift-b", "15.5"))
            self.assertNotEqual(first, cache_key(root, "swift-a", "15.6"))
            (root / "Package.resolved").write_text("dependency")
            self.assertNotEqual(first, cache_key(root, "swift-a", "15.5"))
            (root / "Package.resolved").unlink()
            (root / "Package.swift").write_text("second")
            self.assertNotEqual(first, cache_key(root, "swift-a", "15.5"))

    def test_checkout_cleanup_preserves_build_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "checkout"
            root.mkdir()
            cache_root = Path(directory) / "cache"
            destination = link_build_cache(root, cache_root, "a" * 64)
            marker = destination / "compiled-object"
            marker.write_text("keep across failed jobs")
            self.assertEqual(destination, link_build_cache(root, cache_root, "a" * 64))
            (root / ".build").unlink()
            link_build_cache(root, cache_root, "a" * 64)
            self.assertEqual((root / ".build/compiled-object").read_text(), marker.read_text())

    def test_foreign_build_data_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "checkout"
            root.mkdir()
            cache_root = Path(directory) / "cache"
            (root / ".build").mkdir()
            marker = root / ".build/preserve"
            marker.write_text("original")
            with self.assertRaises(ValueError):
                link_build_cache(root, cache_root, "a" * 64)
            self.assertEqual(marker.read_text(), "original")
            marker.unlink()
            (root / ".build").rmdir()
            (root / ".build").symlink_to(Path(directory) / "foreign")
            with self.assertRaises(ValueError):
                link_build_cache(root, cache_root, "a" * 64)
            self.assertTrue((root / ".build").is_symlink())
            with self.assertRaises(ValueError):
                link_build_cache(root, cache_root, "../foreign")

    def test_main_requires_matching_virtual_machine_and_tools(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Package.swift").write_text("package")
            event_path = root / "event.json"
            event_path.write_text(json.dumps({"repository": {
                "full_name": "stephenlclarke/elite", "fork": False}}))
            environment = {"GITHUB_EVENT_NAME": "push",
                           "GITHUB_REPOSITORY": "stephenlclarke/elite",
                           "GITHUB_ACTOR_ID": "22142777",
                           "GITHUB_EVENT_PATH": str(event_path)}
            for model, swift, sdk in (("Mac17,9", SWIFT, "15.5"),
                                      ("VirtualMac2,1", "Swift 6.4", "15.5"),
                                      ("VirtualMac2,1", SWIFT, "27.0")):
                def fingerprint(*args):
                    return {"sysctl": model, "swift": swift, "xcrun": sdk}[args[0]]
                with self.subTest(model=model, swift=swift, sdk=sdk), \
                        patch.dict(local_runner.os.environ, environment, clear=True), \
                        patch.object(local_runner, "ROOT", root), \
                        patch.object(local_runner.platform, "system", return_value="Darwin"), \
                        patch.object(local_runner.platform, "machine", return_value="arm64"), \
                        patch.object(local_runner, "output", side_effect=fingerprint), \
                        self.assertRaises(ValueError):
                    local_runner.main()
                self.assertFalse((root / ".build").exists())
            with patch.dict(local_runner.os.environ, environment, clear=True), \
                    patch.object(local_runner.platform, "system", return_value="Linux"), \
                    self.assertRaises(ValueError):
                local_runner.main()

    def test_main_prepares_verified_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Package.swift").write_text("package")
            event_path = root / "event.json"
            event_path.write_text(json.dumps({"repository": {
                "full_name": "stephenlclarke/elite", "fork": False}}))
            environment = {"GITHUB_EVENT_NAME": "push",
                           "GITHUB_REPOSITORY": "stephenlclarke/elite",
                           "GITHUB_ACTOR_ID": "22142777",
                           "GITHUB_EVENT_PATH": str(event_path)}
            def fingerprint(*args):
                return {"sysctl": "VirtualMac2,1", "swift": SWIFT,
                        "xcrun": "15.5"}[args[0]]
            capture = io.StringIO()
            with patch.dict(local_runner.os.environ, environment, clear=True), \
                    patch.object(local_runner, "ROOT", root), \
                    patch.object(local_runner.platform, "system", return_value="Darwin"), \
                    patch.object(local_runner.platform, "machine", return_value="arm64"), \
                    patch.object(local_runner, "output", side_effect=fingerprint), \
                    patch.object(Path, "home", return_value=root / "guest-home"), \
                    contextlib.redirect_stdout(capture):
                local_runner.main()
            receipt = json.loads(capture.getvalue())
            self.assertTrue((root / ".build").is_symlink())
            self.assertEqual((root / ".build").resolve(), Path(receipt["cache"]).resolve())


if __name__ == "__main__":
    unittest.main()
