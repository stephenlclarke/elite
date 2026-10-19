import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("showroom_export", Path(__file__).parents[1] / "export-original-fleet-showroom-models.py")
showroom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(showroom)


class OriginalFleetShowroomModelsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.inputs, self.staging = self.root / "inputs", self.root / "staging"
        self.inputs.mkdir()
        self.staging.mkdir()
        self.native = {
            "vertices": [[0, 0, 0], [2, 0, 0], [0, 3, 0], [0, 0, 4]],
            "faces": [[0, 2, 1], [0, 1, 3], [0, 3, 2], [1, 2, 3]],
            "materials": [{"name": "actual", "colour": 0x123456FF, "emissive": True}],
            "faceMaterials": [0] * 4, "license": "MIT", "source": "authored native fixture",
            "paletteName": "retained", "textures": [],
            "faceTextures": [{"texture": -1, "uv": [[0, 0]] * 3}] * 4,
        }
        self.index = {"schema": "l337.complete-original-fleet-index/1", "ships": []}
        self.rows = []
        for number in (1, 2):
            sid = f"SH{number:03}"
            geometry = f"batch-01/native-lod/{sid}-design.toml"
            proposal = {"id": sid}
            if number == 2:
                proposal["coordinateUnits"] = "metres"
            raw = ("proposal = " + showroom.fleet.toml_value(proposal) + "\nnativeDesign = " + showroom.fleet.toml_value(self.native) + "\n").encode()
            hull = self.staging / "original-hulls" / f"{sid}-design.toml"
            hull.parent.mkdir(exist_ok=True)
            hull.write_bytes(raw)
            source = self.inputs / geometry
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_bytes(raw)
            spec_path = f"fleet-specs/{sid}.toml"
            stats = self.inputs / spec_path
            stats.parent.mkdir(exist_ok=True)
            stats.write_text("id = " + json.dumps(sid) + "\n")
            entry = {"id": sid, "geometryFile": geometry, "geometrySHA256": showroom.fleet.digest(raw),
                     "statsFile": spec_path, "statsSHA256": showroom.fleet.digest(stats.read_bytes())}
            self.index["ships"].append(entry)
            self.rows.append({"id": sid, "hull": f"original-hulls/{sid}-design.toml",
                              "sources": [{"path": geometry, "sha256": entry["geometrySHA256"]}]})
        self.write_metadata()

    def write_metadata(self):
        raw = showroom.encoded(self.index)
        (self.inputs / "index.json").write_bytes(raw)
        ready = {"ships": self.rows, "deliveryIndex": {"path": "index.json", "sha256": showroom.fleet.digest(raw)}}
        (self.staging / "readiness.json").write_bytes(showroom.encoded(ready))

    def export(self, name="out"):
        return showroom.export(self.inputs, "index.json", self.staging, self.root / name, expected=2)

    def test_exact_native_fields_units_and_effective_lod_path(self):
        result = self.export()
        self.assertEqual(result["models"], 2)
        self.assertFalse(result["runtimeActivation"])
        first = json.loads((self.root / "out/SH001.json").read_bytes())
        second = json.loads((self.root / "out/SH002.json").read_bytes())
        self.assertEqual(first["nativeDesign"], self.native)
        self.assertEqual(second["nativeDesign"], self.native)
        self.assertNotIn("coordinateUnits", first)
        self.assertEqual(second["coordinateUnits"], "metres")
        self.assertEqual(first["sourcePath"], "batch-01/native-lod/SH001-design.toml")
        self.assertNotIn("game", first)
        self.export("again")
        self.assertEqual((self.root / "out/manifest.json").read_bytes(), (self.root / "again/manifest.json").read_bytes())

    def test_duplicate_or_missing_index_id_refuses(self):
        self.index["ships"][1]["id"] = "SH001"
        self.write_metadata()
        with self.assertRaises(ValueError):
            self.export()

    def test_missing_staging_id_refuses(self):
        self.rows.pop()
        self.write_metadata()
        with self.assertRaises(ValueError):
            self.export()

    def test_altered_hull_hash_refuses(self):
        p = self.staging / "original-hulls/SH001-design.toml"
        p.write_bytes(p.read_bytes() + b"# changed\n")
        with self.assertRaisesRegex(ValueError, "hash"):
            self.export()

    def test_effective_source_path_join_refuses(self):
        self.rows[0]["sources"][0]["path"] = "unsealed-draft/SH001-design.toml"
        self.write_metadata()
        with self.assertRaisesRegex(ValueError, "source"):
            self.export()

    def test_path_escape_refuses(self):
        self.index["ships"][0]["geometryFile"] = "../SH001-design.toml"
        self.write_metadata()
        with self.assertRaises(ValueError):
            self.export()

    def test_missing_and_malformed_native_refuse(self):
        p = self.staging / "original-hulls/SH001-design.toml"
        for native in [None, dict(self.native, faces=[[0, 999, 1]] * 4)]:
            hull = {"proposal": {"id": "SH001"}}
            if native is not None:
                hull["nativeDesign"] = native
            raw = "\n".join(k + " = " + showroom.fleet.toml_value(v) for k, v in hull.items()).encode()
            p.write_bytes(raw)
            sha = showroom.fleet.digest(raw)
            self.index["ships"][0]["geometrySHA256"] = sha
            self.rows[0]["sources"][0]["sha256"] = sha
            self.write_metadata()
            with self.assertRaises(ValueError):
                self.export("bad-" + str(native is None))

    def test_symlink_source_refuses(self):
        p = self.staging / "original-hulls/SH001-design.toml"
        elsewhere = self.root / "elsewhere.toml"
        p.rename(elsewhere)
        p.symlink_to(elsewhere)
        with self.assertRaises(ValueError):
            self.export()


if __name__ == "__main__":
    unittest.main()
