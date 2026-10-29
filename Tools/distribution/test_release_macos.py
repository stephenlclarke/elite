"""Reject mismatched/partial releases and keep every consumer on one generated version."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import homebrew_cask
import package_macos
import release_macos as release
import release_version as version


class ReleaseArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.plan = version.make_plan("v1.4.0", "a" * 40, "b" * 40,
                                      [{"sha": "c" * 40, "subject": "feat: game", "impact": "minor"}], True)
        self.files = release.artifacts(self.plan, self.root)
        self.prefix = version.artifact_prefix(self.plan)
        self.files[self.prefix + ".zip"].parent.mkdir(parents=True)
        archive = b"verified fixture archive"
        self.manifest = {"appVersion": self.plan["version"], "sourceRevision": self.plan["sourceRevision"],
                         "releasePlanSha256": version.plan_digest(self.plan), "archive": self.prefix + ".zip",
                         "archiveBytes": len(archive), "sha256": hashlib.sha256(archive).hexdigest(),
                         "minimumMacOS": "14.0", "architectures": ["arm64", "x86_64"],
                         "signature": "Developer ID Application", "notarized": True,
                         "gatekeeperAccepted": True, "hardenedRuntime": True, "secureTimestamp": True}
        self.files[self.prefix + ".zip"].write_bytes(archive)
        self.files[self.prefix + ".sha256"].write_text(self.manifest["sha256"] + "  " + self.prefix + ".zip\n")
        for suffix, value in [(".json", self.manifest), ("-release-plan.json", self.plan),
                              ("-notarization.json", {"status": "Accepted"})]:
            self.files[self.prefix + suffix].write_text(json.dumps(value))
        self.assets = [{"name": name, "size": path.stat().st_size,
                        "digest": "sha256:" + release.file_digest(path), "state": "uploaded",
                        "browser_download_url": "https://example.invalid/" + name}
                       for name, path in self.files.items()]
        self.draft = {"tag_name": self.plan["tag"], "draft": True, "prerelease": False,
                      "target_commitish": self.plan["sourceRevision"], "assets": self.assets}
        self.published = {**self.draft, "draft": False, "html_url": "https://example.invalid/release"}

    def github(self, path, draft=None, conclusion="success"):
        if path.startswith("commits/"):
            return {"check_runs": [{"name": "quality", "head_sha": self.plan["sourceRevision"],
                                     "app": {"id": 15368}, "id": 1, "conclusion": conclusion}]}
        return draft or self.draft

    def publish(self, draft=None, optional=None, conclusion="success"):
        with patch.object(release, "require_main"), \
             patch.object(release, "github", side_effect=lambda path: self.github(path, draft, conclusion)), \
             patch.object(release, "optional_github", side_effect=optional or [None, None]), \
             patch.object(release, "tag_revision", return_value=self.plan["sourceRevision"]), \
             patch.object(release, "published_plan", return_value=self.published), \
             patch.object(release, "command") as command:
            self.commands = command
            return release.publish(self.plan, self.root)

    def test_one_plan_drives_bundle_archive_tag_readme_and_cask(self):
        class StopBeforeNativePackaging(Exception):
            pass
        (self.root / ".build").mkdir()
        with patch.object(package_macos, "ROOT", self.root), \
             patch.object(package_macos, "source_checkpoint", return_value=self.plan["sourceRevision"]), \
             patch.object(version, "load_plan", return_value=self.plan), \
             patch.object(package_macos, "run", return_value=SimpleNamespace(stdout=str(self.root))) as build_tool, \
             patch.object(package_macos, "create_bundle", side_effect=StopBeforeNativePackaging) as bundle:
            with self.assertRaises(StopBeforeNativePackaging):
                package_macos.package(SimpleNamespace(release_plan=Path("plan.json"), version="99.0.0"))
            self.assertEqual(bundle.call_args.args[2:], (self.plan["version"], self.plan["sourceRevision"]))
            expected = ("swift", "build", "--configuration", "release", "--scratch-path",
                        str(self.root / ".build/distribution"), "--arch", "arm64", "--arch", "x86_64",
                        "--jobs", "1", "-Xswiftc", "-disable-batch-mode")
            self.assertEqual([call.args for call in build_tool.call_args_list],
                             [expected, (*expected, "--show-bin-path")])
            self.assertEqual([call.kwargs for call in build_tool.call_args_list], [{}, {"capture": True}])
        readme = release.readme_text("The [published tap cask](https://example.invalid) is older.\n", self.plan, self.manifest)
        self.assertIn("Elite 1.5.0", readme)
        self.assertIn("/v1.5.0/Elite-1.5.0-universal.zip", readme)
        self.assertEqual(release.readme_text(readme, self.plan, self.manifest), readme)
        cask = homebrew_cask.render_cask(self.manifest, self.plan["sourceRevision"], source_revision=True)
        self.assertEqual(homebrew_cask.existing_release(cask), ("1.5.0", self.plan["sourceRevision"]))
        receipt = self.publish()
        self.assertEqual(receipt["tag"], "v1.5.0")
        create = next(call for call in self.commands.call_args_list if call.args[:3] == ("gh", "release", "create"))
        self.assertEqual(create.args[3], self.plan["tag"])
        self.assertIn(self.plan["sourceRevision"], create.args)
        self.assertTrue(all(str(path) in create.args for path in self.files.values()))

    def test_manifest_version_source_or_plan_tamper_is_rejected(self):
        for key, value in [("appVersion", "9.0.0"), ("sourceRevision", "d" * 40),
                           ("releasePlanSha256", "0" * 64), ("notarized", False)]:
            broken = {**self.manifest, key: value}
            self.files[self.prefix + ".json"].write_text(json.dumps(broken))
            with self.subTest(key=key), self.assertRaises(ValueError):
                release.verify_local(self.plan, self.root)
        self.files[self.prefix + ".json"].write_text(json.dumps(self.manifest))
        self.files[self.prefix + ".zip"].write_bytes(b"different bytes")
        with self.assertRaises(ValueError):
            release.verify_local(self.plan, self.root)

    def test_incomplete_or_corrupt_upload_never_publishes_or_writes_success(self):
        corrupt = copy.deepcopy(self.assets)
        corrupt[0]["digest"] = "sha256:" + "0" * 64
        for assets in (self.assets[:-1], corrupt):
            with self.subTest(assets=assets), self.assertRaises(ValueError):
                self.publish(draft={**self.draft, "assets": assets})
            self.assertFalse(any(call.args[:3] == ("gh", "release", "edit") for call in self.commands.call_args_list))
            self.assertFalse((self.root / "dist/macos" / (self.prefix + "-published.json")).exists())

    def test_missing_quality_pass_stops_before_tag_or_release_mutation(self):
        with self.assertRaises(ValueError):
            self.publish(conclusion=None)
        self.commands.assert_not_called()

    def test_only_matching_draft_can_resume_and_existing_assets_are_never_overwritten(self):
        partial = {**self.draft, "assets": self.assets[:2]}
        self.publish(optional=[partial, {"object": {"sha": self.plan["sourceRevision"]}}])
        upload = next(call for call in self.commands.call_args_list if call.args[:3] == ("gh", "release", "upload"))
        self.assertNotIn("--clobber", upload.args)
        self.assertEqual(set(upload.args[6:]), {str(path) for name, path in self.files.items()
                                              if name not in {asset["name"] for asset in self.assets[:2]}})
        with self.assertRaises(ValueError):
            self.publish(optional=[{**self.draft, "target_commitish": "wrong source"}])

    def test_coverage_entrypoint_delegates_once_and_preserves_phase_failure(self):
        script = self.root / "script/coverage.sh"
        script.parent.mkdir()
        shutil.copy2(Path(release.__file__).resolve().parents[2] / "script/coverage.sh", script)
        tools = self.root / "bin"
        tools.mkdir()
        log = self.root / "delegation.log"
        for status in (0, 5):
            helper = tools / "python3"
            helper.write_text('#!/bin/sh\nprintf "%s\\n" "$PWD" "$@" > "$DELEGATION_LOG"\nexit ' + str(status) + '\n')
            helper.chmod(0o700)
            result = subprocess.run(["/bin/bash", str(script)], cwd=self.root.parent,
                                    env={"PATH": str(tools) + ":/usr/bin:/bin", "DELEGATION_LOG": str(log)},
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, status, result.stderr)
            lines = log.read_text().splitlines()
            self.assertEqual(Path(lines[0]).resolve(), self.root.resolve())
            self.assertEqual(lines[1:], ["Tools/CI/quality_phase_checkpoints.py", "normal"])


if __name__ == "__main__":
    unittest.main()
