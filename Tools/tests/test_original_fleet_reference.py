import csv
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("reference", Path(__file__).resolve().parents[1] / "export-original-fleet-reference.py")
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


class OriginalFleetReferenceTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.staging = self.root / "staging"
        (self.staging / "specs").mkdir(parents=True)
        self.raw = b'id = "SH001"\nname = "Original trader"\nfamily = "original"\nrole = "trader"\nplayerFlyable = true\npurchasePolicy = "plughQuestFabrication"\ngame = {price = 0, cargo = 63, speed = 34.8}\n'
        (self.staging / "specs/SH001.toml").write_bytes(self.raw)
        self.entry = {"id": "SH001", "spec": "specs/SH001.toml", "sources": [{"path": "fleet-specs/SH001.toml", "sha256": TOOL.fingerprint(self.raw)}], "geometryAvailable": False, "runtimeReady": False, "currentLoaderCompatible": False, "dependencies": ["missing-mesh", "quest-gate"], "gameValidityIssues": ["price is zero"], "missingLoaderFields": ["catalogue"], "unsupportedSpecFields": ["purchasePolicy"]}
        self.ready = {"schema": "l337.original-fleet-staging/1", "ships": [self.entry], "dependencyDefinitions": {"missing-mesh": "No approved mesh", "quest-gate": "Native gate required"}}
        self.write_ready()

    def write_ready(self):
        (self.staging / "readiness.json").write_text(json.dumps(self.ready))

    def test_complete_values_gaps_and_deterministic_output_without_geometry(self):
        a = TOOL.export(self.staging, self.root / "a", expected=1)
        b = TOOL.export(self.staging, self.root / "b", expected=1)
        self.assertEqual(a, b)
        for file in (self.root / "a").iterdir():
            self.assertEqual(file.read_bytes(), (self.root / "b" / file.name).read_bytes())
        with (self.root / "a/fleet-reference.csv").open(newline="") as stream:
            row = next(csv.DictReader(stream))
        self.assertEqual(row["game.price"], "0")
        self.assertEqual(row["game.speed"], "34.8")
        self.assertEqual(row["unit.speed"], "raw authored units")
        self.assertEqual(row["unit.cargo"], "t")
        self.assertEqual(row["authored_access"], "")
        self.assertEqual(row["runtime_ready"], "false")
        self.assertEqual(json.loads(row["authored_spec_json"])["game"]["cargo"], 63)
        self.assertIn("missing-mesh", row["loader_dependencies"])
        self.assertFalse(a["geometryRead"])

    def test_csv_and_markdown_escape_without_losing_authored_name(self):
        name = '=SUM(1,2) <img> | [unsafe] "quote"'
        raw = self.raw.replace(b'"Original trader"', json.dumps(name).encode())
        (self.staging / "specs/SH001.toml").write_bytes(raw)
        self.entry["sources"][0]["sha256"] = TOOL.fingerprint(raw)
        self.write_ready()
        TOOL.export(self.staging, self.root / "out", 1)
        with (self.root / "out/fleet-reference.csv").open(newline="") as stream:
            row = next(csv.DictReader(stream))
        self.assertEqual(row["name"], "'" + name)
        self.assertEqual(json.loads(row["authored_spec_json"])["name"], name)
        markdown = (self.root / "out/fleet-reference.md").read_text()
        self.assertNotIn("<img>", markdown)
        self.assertNotIn("[unsafe]", markdown)

    def test_duplicate_traversal_fingerprint_and_output_symlink_refusal(self):
        self.ready["ships"].append(self.entry)
        self.write_ready()
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            TOOL.export(self.staging, self.root / "duplicate", 2)
        self.ready["ships"].pop()
        self.entry["spec"] = "../unsafe.toml"
        self.write_ready()
        with self.assertRaises(ValueError):
            TOOL.export(self.staging, self.root / "unsafe", 1)
        self.entry["spec"] = "specs/SH001.toml"
        self.entry["sources"][0]["sha256"] = "0" * 64
        self.write_ready()
        with self.assertRaisesRegex(ValueError, "fingerprint"):
            TOOL.export(self.staging, self.root / "bad", 1)
        empty = self.root / "empty"
        empty.mkdir()
        link = self.root / "link"
        link.symlink_to(empty, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "Symlink"):
            TOOL.export(self.staging, link, 1)
        self.assertEqual(list(empty.iterdir()), [])

    def test_display_spec_keeps_missing_performance_explicit(self):
        raw = b'id = "SH001"\nname = "Original station"\nrole = "station"\nplayerFlyable = false\npurchasePolicy = "never"\n'
        (self.staging / "specs/SH001.toml").write_bytes(raw)
        self.entry["sources"][0]["sha256"] = TOOL.fingerprint(raw)
        self.write_ready()
        TOOL.export(self.staging, self.root / "display", 1)
        self.assertIn("Not authored (display object)", (self.root / "display/fleet-reference.md").read_text())
        with (self.root / "display/fleet-reference.csv").open(newline="") as stream:
            row = next(csv.DictReader(stream))
        self.assertEqual(row["game.price"], "")
        self.assertEqual(row["authored_player_flyable"], "false")


if __name__ == "__main__":
    unittest.main()
