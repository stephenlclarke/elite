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
        (self.root / "Casks").mkdir()
        self.cask = self.root / "Casks/elite.rb"
        shutil.copy2(historical.ROOT / "Casks/elite.rb", self.cask)

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
