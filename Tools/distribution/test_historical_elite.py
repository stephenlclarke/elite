"""Keep the exact published Elite delivery separate from current L337 authority."""

import io
from pathlib import Path
import shutil
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

import historical_elite as historical
import homebrew_cask
import release_version


class HistoricalEliteTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copytree(historical.ROOT / "releases/receipts/Elite-1.5.0",
                        self.root / "releases/receipts/Elite-1.5.0")
        shutil.copytree(historical.ROOT / "releases/receipts/Elite-1.5.1",
                        self.root / "releases/receipts/Elite-1.5.1")
        (self.root / "Casks").mkdir()
        self.cask = self.root / "Casks/elite.rb"
        shutil.copy2(historical.ROOT / "releases/receipts/Elite-1.5.0/elite.rb", self.cask)

    def test_exact_public_receipts_and_unchanged_cask_verify_without_network_or_writes(self):
        before = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        opener = Mock(side_effect=AssertionError("No network during the historical metadata check"))
        historical.verify_historical(self.cask, root=self.root, opener=opener)
        manifest, plan = historical.metadata(self.root)
        self.assertEqual(manifest["sourceRevision"], historical.SOURCE)
        self.assertEqual(plan["repository"], "stephenlclarke/elite")
        self.assertEqual(manifest["archive"], "Elite-1.5.0-universal.zip")
        self.assertEqual(before, {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()})
        self.assertFalse((self.root / "Casks/l337.rb").exists())
        opener.assert_not_called()

    def test_each_changed_receipt_and_changed_cask_refuse(self):
        for suffix in historical.PINS:
            path = self.root / "releases/receipts/Elite-1.5.0" / (historical.PREFIX + suffix)
            original = path.read_bytes()
            path.write_bytes(original + b" ")
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                historical.verify_historical(self.cask, root=self.root)
            path.write_bytes(original)
        self.cask.write_text(self.cask.read_text().replace('cask "elite"', 'cask "l337"'))
        with self.assertRaises(ValueError):
            historical.verify_historical(self.cask, root=self.root)

    def test_actual_historical_manifest_cannot_generate_or_publish_current_l337(self):
        manifest, plan = historical.metadata(self.root)
        with self.assertRaises(ValueError):
            homebrew_cask.validate_manifest(manifest)
        with self.assertRaises(ValueError):
            homebrew_cask.render_cask(manifest, historical.SOURCE)
        with self.assertRaises(ValueError):
            release_version.validate_artifact(plan, manifest)
        with patch.object(release_version, "command", side_effect=AssertionError("No Git or API lookup")), \
             self.assertRaises(ValueError):
            release_version.validate_plan(plan)
        options = SimpleNamespace(release_plan=Path("plan.json"), check=False, verify_download=False)
        with patch.object(homebrew_cask, "load_plan", return_value=plan), \
             patch.object(homebrew_cask, "public_json", return_value=plan), \
             patch.object(homebrew_cask, "published_plan") as publish, self.assertRaises(ValueError):
            homebrew_cask.planned_release(options, self.root / "Casks/l337.rb")
        publish.assert_not_called()

    def test_historical_download_is_fixed_and_corrupt_bytes_refuse(self):
        opener = Mock(return_value=io.BytesIO(b"wrong archive"))
        with self.assertRaises(ValueError):
            historical.verify_historical(self.cask, download=True, root=self.root, opener=opener)
        opener.assert_called_once_with(
            "https://github.com/stephenlclarke/elite/releases/download/v1.5.0/Elite-1.5.0-universal.zip",
            timeout=60)

    def test_default_historical_check_cannot_generate_an_unpublished_l337_cask(self):
        with patch.object(homebrew_cask, "ROOT", self.root), \
             patch.object(sys, "argv", ["homebrew_cask.py", "--check"]), \
             patch.object(historical, "verify_historical") as verify, \
             patch.object(homebrew_cask, "planned_release") as current:
            homebrew_cask.main()
        verify.assert_called_once_with(self.cask, download=False)
        current.assert_not_called()
        self.assertFalse((self.root / "Casks/l337.rb").exists())

    def current_cask(self) -> Path:
        """Use exact public 1.5.1 bytes without changing the retained 1.5.0 fixture."""
        current = self.root / "current-elite.rb"
        shutil.copy2(historical.ROOT / "Casks/elite.rb", current)
        return current

    def test_151_exact_receipts_current_cask_and_source_remain_closed_without_network(self):
        current = self.current_cask()
        before = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        opener = Mock(side_effect=AssertionError("No network during sealed metadata checks"))
        historical.verify_historical(current, root=self.root, opener=opener)
        historical.verify_historical(self.cask, root=self.root, opener=opener)
        manifest, plan = historical.metadata(self.root, "1.5.1")
        self.assertEqual(manifest["sourceRevision"], historical.SOURCE_151)
        self.assertEqual(plan["sourceRevision"], historical.SOURCE_151)
        self.assertEqual(plan["repository"], "stephenlclarke/elite")
        self.assertEqual(plan["tag"], "v1.5.1")
        self.assertEqual(manifest["archive"], "Elite-1.5.1-universal.zip")
        self.assertEqual(manifest["sha256"],
                         "8398f6b03e44796ecc88ba3ad0b28a9d72fffd5f9d47a96d43942de0d51b941b")
        self.assertEqual(before, {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()})
        self.assertFalse((self.root / "Casks/l337.rb").exists())
        opener.assert_not_called()

    def test_151_every_changed_receipt_and_changed_current_cask_refuse(self):
        current = self.current_cask()
        for suffix in historical.PINS_151:
            path = self.root / "releases/receipts/Elite-1.5.1" / (historical.PREFIX_151 + suffix)
            original = path.read_bytes()
            path.write_bytes(original + b" ")
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                historical.verify_historical(current, root=self.root)
            path.write_bytes(original)
        current.write_text(current.read_text().replace('version "1.5.1"', 'version "1.5.2"'))
        with self.assertRaises(ValueError):
            historical.verify_historical(current, root=self.root)
        historical.verify_historical(self.cask, root=self.root)

    def test_default_check_reaches_real_151_verifier_without_generating_l337(self):
        shutil.copy2(self.current_cask(), self.cask)
        before = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        real_verify = historical.verify_historical

        def verify(cask: Path, download: bool = False) -> None:
            # The CLI keeps its actual call signature; only its fixture root is isolated.
            return real_verify(cask, download=download, root=self.root)
        with patch.object(homebrew_cask, "ROOT", self.root), \
             patch.object(sys, "argv", ["homebrew_cask.py", "--check"]), \
             patch.object(historical, "verify_historical", side_effect=verify) as checked, \
             patch.object(homebrew_cask, "planned_release") as current, \
             patch.object(historical.urllib.request, "urlopen", side_effect=AssertionError("No network")), \
             patch.object(sys, "stdout", new_callable=io.StringIO) as output:
            homebrew_cask.main()
        checked.assert_called_once_with(self.cask, download=False)
        self.assertEqual(output.getvalue(),
                         "Historical Elite cask verified; no L337 publication is implied.\n")
        self.assertNotIn("1.5.0", output.getvalue())
        current.assert_not_called()
        self.assertFalse((self.root / "Casks/l337.rb").exists())
        self.assertEqual(before, {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()})

    def test_two_versions_cannot_cross_join_their_receipts(self):
        current = self.current_cask()
        directory = self.root / "releases/receipts/Elite-1.5.1"
        for suffix in historical.PINS_151:
            path = directory / (historical.PREFIX_151 + suffix)
            original = path.read_bytes()
            old = self.root / "releases/receipts/Elite-1.5.0" / (historical.PREFIX + suffix)
            path.write_bytes(old.read_bytes())
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                historical.verify_historical(current, root=self.root)
            path.write_bytes(original)
        historical.verify_historical(current, root=self.root)
        historical.verify_historical(self.cask, root=self.root)

    def test_151_download_url_is_fixed_bounded_and_corrupt_archive_refuses(self):
        current = self.current_cask()
        response = Mock()
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=False)
        response.read.return_value = b"wrong archive"
        opener = Mock(return_value=response)
        with self.assertRaises(ValueError):
            historical.verify_historical(current, download=True, root=self.root, opener=opener)
        opener.assert_called_once_with(
            "https://github.com/stephenlclarke/elite/releases/download/v1.5.1/Elite-1.5.1-universal.zip",
            timeout=60)
        manifest, _ = historical.metadata(self.root, "1.5.1")
        response.read.assert_called_once_with(manifest["archiveBytes"] + 1)

    def test_151_cannot_generate_or_publish_current_l337(self):
        manifest, plan = historical.metadata(self.root, "1.5.1")
        with self.assertRaises(ValueError):
            homebrew_cask.validate_manifest(manifest)
        with self.assertRaises(ValueError):
            homebrew_cask.render_cask(manifest, historical.SOURCE_151)
        with self.assertRaises(ValueError):
            release_version.validate_artifact(plan, manifest)
        with patch.object(release_version, "command", side_effect=AssertionError("No Git or API")), \
             self.assertRaises(ValueError):
            release_version.validate_plan(plan)
        options = SimpleNamespace(release_plan=Path("plan.json"), check=False, verify_download=False)
        with patch.object(homebrew_cask, "load_plan", return_value=plan), \
             patch.object(homebrew_cask, "public_json", return_value=plan), \
             patch.object(homebrew_cask, "published_plan") as publish, self.assertRaises(ValueError):
            homebrew_cask.planned_release(options, self.root / "Casks/l337.rb")
        publish.assert_not_called()

    def test_unknown_version_and_unpinned_cask_cannot_register_a_release(self):
        for version in ("1.5.2", "1.6.0", "latest", "../../other", "1.5.0/../1.5.1"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                historical.metadata(self.root, version)
        current = self.current_cask()
        current.write_bytes(current.read_bytes() + b"\n")
        with self.assertRaises(ValueError):
            historical.verify_historical(current, root=self.root)
