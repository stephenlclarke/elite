"""Exercise the real Sonar entry point without network access or Swift builds."""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class SonarCheckpointTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="elite-sonar-checkpoint-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for directory in ("script", "Tools/distribution", "Sources", "bin"):
            (self.root / directory).mkdir(parents=True)
        for name in ("script/sonar.sh", "Tools/distribution/package_macos.py"):
            shutil.copy2(ROOT / name, self.root / name)
        (self.root / ".gitignore").write_text(".build/\nreports/\n__pycache__/\n")
        (self.root / "Sources/Fixture.swift").write_text("// committed fixture\n")
        (self.root / "Tools/verify-sonar-settings.py").write_text(
            "from pathlib import Path\n"
            "Path('reports').mkdir(exist_ok=True)\n"
            "Path('reports/settings-checked').write_text('checked')\n"
        )
        self.set_coverage("mkdir -p reports\nprintf covered > reports/coverage-checked\n")
        scanner = self.root / "bin/sonar-scanner"
        scanner.write_text(
            "#!/usr/bin/env python3\n"
            "import json, sys\n"
            "from pathlib import Path\n"
            "Path('reports/scanner-arguments.json').write_text(json.dumps(sys.argv[1:]))\n"
        )
        scanner.chmod(0o755)
        self.git("init", "--initial-branch=main")
        self.git("config", "user.name", "Checkpoint Fixture")
        self.git("config", "user.email", "checkpoint@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", "/dev/null")
        self.commit()
        self.revision = self.git("rev-parse", "HEAD").strip()

    def git(self, *arguments):
        result = subprocess.run(
            ["git", *arguments], cwd=self.root, text=True, capture_output=True, check=True
        )
        return result.stdout

    def commit(self):
        self.git("add", ".")
        self.git("commit", "-m", "test: committed checkpoint fixture")

    def set_coverage(self, commands):
        path = self.root / "script/coverage.sh"
        path.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + commands)
        path.chmod(0o755)

    def run_entrypoint(self):
        environment = os.environ.copy()
        # A local sentinel only; the settings/scanner fixtures never contact a service.
        environment["SONAR_TOKEN"] = "offline-checkpoint-fixture"
        environment["PATH"] = str(self.root / "bin") + os.pathsep + environment["PATH"]
        return subprocess.run(
            ["bash", "script/sonar.sh"], cwd=self.root, env=environment,
            text=True, capture_output=True, check=False,
        )

    def assert_no_scanner(self, result):
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "reports/scanner-arguments.json").exists())

    def test_clean_main_publishes_the_initial_exact_commit(self):
        result = self.run_entrypoint()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.revision), 40)
        self.assertEqual(
            json.loads((self.root / "reports/scanner-arguments.json").read_text()),
            ["-Dsonar.projectVersion=" + self.revision],
        )
        self.assertTrue((self.root / "reports/settings-checked").exists())
        self.assertTrue((self.root / "reports/coverage-checked").exists())

    def test_untracked_maintained_inputs_fail_before_settings_or_coverage(self):
        for name in (
            "Sources/Uncommitted.swift", "Tests/Uncommitted.swift", "Tools/uncommitted.py",
            "script/uncommitted.sh", "Resources/uncommitted.txt", "Package.swift",
            "Package.resolved", "Makefile",
        ):
            with self.subTest(name=name):
                path = self.root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("uncommitted\n")
                result = self.run_entrypoint()
                self.assert_no_scanner(result)
                self.assertIn("Commit maintained source files", result.stderr)
                self.assertFalse((self.root / "reports/settings-checked").exists())
                self.assertFalse((self.root / "reports/coverage-checked").exists())
                path.unlink()

    def test_tracked_modification_fails_before_settings_or_coverage(self):
        (self.root / "Sources/Fixture.swift").write_text("// uncommitted change\n")
        result = self.run_entrypoint()
        self.assert_no_scanner(result)
        self.assertIn("Commit tracked changes", result.stderr)
        self.assertFalse((self.root / "reports/settings-checked").exists())

    def test_ignored_build_outputs_do_not_block_analysis(self):
        (self.root / ".build").mkdir()
        (self.root / ".build/artifact").write_text("generated\n")
        result = self.run_entrypoint()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_untracked_source_created_during_coverage_blocks_publication(self):
        self.set_coverage("printf unexpected > Sources/Unexpected.swift\n")
        self.commit()
        result = self.run_entrypoint()
        self.assert_no_scanner(result)
        self.assertIn("Commit maintained source files", result.stderr)

    def test_tracked_source_changed_during_coverage_blocks_publication(self):
        self.set_coverage("printf changed > Sources/Fixture.swift\n")
        self.commit()
        result = self.run_entrypoint()
        self.assert_no_scanner(result)
        self.assertIn("Commit tracked changes", result.stderr)

    def test_new_clean_commit_during_coverage_blocks_publication(self):
        self.set_coverage("git commit --allow-empty -m 'test: changed checkpoint'\n")
        self.commit()
        result = self.run_entrypoint()
        self.assert_no_scanner(result)
        self.assertIn("Source checkpoint changed", result.stderr)

    def test_non_main_fails_before_settings_or_coverage(self):
        self.git("switch", "-c", "feature/fixture")
        result = self.run_entrypoint()
        self.assert_no_scanner(result)
        self.assertIn("must run on main", result.stderr)
        self.assertFalse((self.root / "reports/settings-checked").exists())

    def test_branch_changed_during_coverage_blocks_publication(self):
        self.set_coverage("git switch -c feature/changed-during-coverage\n")
        self.commit()
        result = self.run_entrypoint()
        self.assert_no_scanner(result)
        self.assertIn("must run on main", result.stderr)


if __name__ == "__main__":
    unittest.main()
