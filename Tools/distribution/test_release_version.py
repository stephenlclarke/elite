"""Exercise actual release-history boundaries without network or native builds."""
import copy
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import release_version as version


class ConventionalVersionTests(unittest.TestCase):
    def test_types_and_breaking_markers(self):
        for message, expected in [
            ("feat: new hull", "minor"), ("fix(ui): repair", "patch"),
            ("perf(core): reduce copies", "patch"), ("docs: guide", "none"),
            ("chore: archive", "none"), ("test: add coverage", "none"),
            ("feat(core)!: change contract", "major"), ("docs!: remove API", "major"),
            ("fix: change\n\nBREAKING CHANGE: source schema", "major"),
            ("fix: change\n\nBREAKING-CHANGE: source schema", "major"),
            ("docs: example\n\n    BREAKING CHANGE: quoted", "none"),
        ]:
            with self.subTest(message=message):
                self.assertEqual(version.impact(message), expected)

    def test_nonconventional_headers_are_not_silently_ignored(self):
        for message in ("Fix the game", "feat:no space", "fix: ", "Feat: uppercase", "",
                        "fix: malformed footer\n\nBREAKING CHANGE:"):
            with self.subTest(message=message), self.assertRaises(ValueError):
                version.impact(message)

    def test_maximum_bump_and_documentation_only_no_release(self):
        for impacts, expected in [(["patch"], "1.4.1"), (["minor", "patch"], "1.5.0"),
                                  (["major", "minor"], "2.0.0"), (["none"], None), ([], None)]:
            plan = version.make_plan("v1.4.0", "a" * 40, "b" * 40,
                                     [{"impact": change} for change in impacts], True)
            self.assertEqual(plan["version"], expected)
            self.assertEqual(plan["tag"], "v" + expected if expected else None)
            self.assertEqual(plan["releaseRequired"], expected is not None)

    def test_stable_versions_reject_aliases_and_prereleases(self):
        for invalid in ("01.4.0", "1.04.0", "1.4", "1.4.0-rc1", "latest"):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                version.semver(invalid)

    def test_only_published_stable_ancestors_can_be_the_base(self):
        releases = [{"tag_name": tag, "draft": draft, "prerelease": pre}
                    for tag, draft, pre in [("v1.4.0", False, False), ("v9.0.0", False, False),
                                             ("v10.0.0", True, False), ("v11.0.0", False, True)]]
        def run(args, **kwargs):
            return subprocess.CompletedProcess(args, 1 if "v9" in args[-2] else 0)
        with patch.object(version, "command", side_effect=lambda *args, **kwargs: args[-1]), \
             patch.object(version.subprocess, "run", side_effect=run):
            self.assertEqual(version.latest_published_ancestor(releases, "HEAD")[0], "v1.4.0")
        with self.assertRaises(ValueError):
            version.latest_published_ancestor([], "HEAD")


class GitHistoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.git("init", "-b", "main")
        self.counter = 0
        self.base = self.commit("chore: released baseline")
        self.git("tag", "v1.4.0")

    def git(self, *args):
        return subprocess.check_output(["git", "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
                                        "-c", "user.name=Release Test", "-c", "user.email=release@example.invalid",
                                        *args], cwd=self.root, stderr=subprocess.PIPE, text=True).strip()

    def commit(self, message):
        self.counter += 1
        (self.root / "file").write_text(str(self.counter))
        self.git("add", "file")
        self.git("commit", "-m", message)
        return self.git("rev-parse", "HEAD")

    def test_whole_dag_counts_feature_once_and_excludes_actual_merge_commit(self):
        self.git("switch", "-c", "feature")
        feature = self.commit("feat: new equipment")
        self.git("switch", "main")
        self.git("merge", "--no-ff", "feature", "-m", "chore(merge): integrate equipment")
        records = version.history(self.base, "HEAD", self.root)
        self.assertEqual([record["sha"] for record in records], [feature])
        self.assertEqual(version.make_plan("v1.4.0", self.base, "HEAD", records, False)["version"], "1.5.0")

    def test_squash_is_one_actual_conventional_commit_including_breaking_footer(self):
        self.git("switch", "-c", "feature")
        self.commit("feat: one")
        self.commit("fix: two")
        self.git("switch", "main")
        self.git("merge", "--squash", "feature")
        self.git("commit", "-m", "feat: combined\n\nBREAKING CHANGE: replace the public contract")
        records = version.history(self.base, "HEAD", self.root)
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["impact"], "major")

    def test_calculated_existing_tag_is_refused(self):
        self.commit("feat: candidate")
        self.git("tag", "v1.5.0")
        original = version.command
        def command(*args, **kwargs):
            if args[:3] == ("git", "fetch", "origin"):
                return ""
            if args[:2] == ("gh", "api"):
                return json.dumps([[{"tag_name": "v1.4.0", "draft": False, "prerelease": False}]])
            return original(*args, **kwargs)
        with patch.object(version, "command", side_effect=command), self.assertRaisesRegex(ValueError, "already exists"):
            version.generate(preview=True, root=self.root)

    def test_saved_plan_rejects_version_source_history_preview_and_no_release_drift(self):
        head = self.commit("fix: candidate")
        plan = version.make_plan("v1.4.0", self.base, head, version.history(self.base, head, self.root), True)
        def github(path):
            if path.startswith("releases/"):
                return {"tag_name": "v1.4.0", "draft": False, "prerelease": False}
            return {"object": {"type": "commit", "sha": self.base}}
        with patch.object(version, "github", side_effect=github):
            self.assertEqual(version.validate_plan(plan, self.root), plan)
            for key, value in [("version", "9.0.0"), ("sourceRevision", "0" * 40),
                               ("historySha256", "0" * 64), ("authoritative", False), ("schema", True)]:
                broken = copy.deepcopy(plan)
                broken[key] = value
                with self.subTest(key=key), self.assertRaises((ValueError, subprocess.CalledProcessError)):
                    version.validate_plan(broken, self.root)
            no_release = version.make_plan("v1.4.0", self.base, self.base, [], True)
            with self.assertRaisesRegex(ValueError, "documentation-only"):
                version.validate_plan(no_release, self.root)


if __name__ == "__main__":
    unittest.main()
