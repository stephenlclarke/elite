"""Check trust rejection and preservation of incremental build data."""

from pathlib import Path
import contextlib
import io
import json
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import local_runner
from crash_artifacts import confined
from local_runner import SWIFT, cache_key, clean_checkout, prepare_build_cache, require_trusted_push


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
            root = (Path(directory) / "checkout").resolve()
            root.mkdir()
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            (root / "Sources").mkdir()
            (root / "Sources/Kept.swift").write_text("tracked source")
            subprocess.run(["git", "add", "Sources/Kept.swift"], cwd=root, check=True)
            (root / "Sources/Unexpected.swift").write_text("remove stale input")
            destination = prepare_build_cache(root, "a" * 64)
            marker = destination / "compiled-object"
            marker.write_text("keep across failed jobs")
            self.assertEqual(destination, prepare_build_cache(root, "a" * 64))
            clean_checkout(root)
            self.assertEqual((root / ".build/compiled-object").read_text(), marker.read_text())
            self.assertTrue((root / "Sources/Kept.swift").is_file())
            self.assertFalse((root / "Sources/Unexpected.swift").exists())
            self.assertFalse(destination.is_symlink())
            self.assertEqual(confined(destination, root), destination.resolve())

    def test_incompatible_owned_cache_is_rebuilt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            destination = prepare_build_cache(root, "a" * 64)
            (destination / "old-object").write_text("old compiler")
            prepare_build_cache(root, "b" * 64)
            self.assertFalse((destination / "old-object").exists())
            identity = json.loads((destination / "elite-ci-cache.json").read_text())
            self.assertEqual(identity["key"], "b" * 64)

    def test_foreign_build_data_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "checkout"
            root.mkdir()
            (root / ".build").mkdir()
            marker = root / ".build/preserve"
            marker.write_text("original")
            with self.assertRaises(ValueError):
                prepare_build_cache(root, "a" * 64)
            self.assertEqual(marker.read_text(), "original")
            identity = root / ".build/elite-ci-cache.json"
            for value in ({"owner": "foreign", "key": "a" * 64},
                          {"owner": "elite-ci", "key": "../foreign"}, []):
                identity.write_text(json.dumps(value))
                with self.subTest(identity=value), self.assertRaises(ValueError):
                    prepare_build_cache(root, "a" * 64)
                self.assertEqual(marker.read_text(), "original")
            identity.unlink()
            marker.unlink()
            (root / ".build").rmdir()
            (root / ".build").write_text("foreign file")
            with self.assertRaises(ValueError):
                prepare_build_cache(root, "a" * 64)
            self.assertEqual((root / ".build").read_text(), "foreign file")
            (root / ".build").unlink()
            (root / ".build").symlink_to(Path(directory) / "foreign")
            with self.assertRaises(ValueError):
                prepare_build_cache(root, "a" * 64)
            self.assertTrue((root / ".build").is_symlink())
            with self.assertRaises(ValueError):
                prepare_build_cache(root, "../foreign")

    def test_observed_swift_driver_prefix_keeps_exact_compiler_identity(self):
        for prefix in ("", "swift-driver version: 1.120.5 "):
            self.assertTrue(local_runner.matching_swift_version(prefix + SWIFT + "\nTarget: arm64-apple-macosx15.0"))
        for version in ("", SWIFT.replace("6.1.2", "6.4.1"),
                        "swift-driver version: 9.9 " + SWIFT):
            self.assertFalse(local_runner.matching_swift_version(version))

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
                    patch.object(local_runner, "clean_checkout"), \
                    contextlib.redirect_stdout(capture):
                local_runner.main()
            receipt = json.loads(capture.getvalue())
            self.assertTrue((root / ".build").is_dir())
            self.assertFalse((root / ".build").is_symlink())
            self.assertEqual((root / ".build").resolve(), Path(receipt["cache"]).resolve())


if __name__ == "__main__":
    unittest.main()
