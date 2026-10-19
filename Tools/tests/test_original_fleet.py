"""Bounded offline tests: original data joins, explicit gaps and safe staging."""

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import tomllib
import unittest


TOOL = Path(__file__).resolve().parents[1] / "compile-original-fleet.py"
SPEC = importlib.util.spec_from_file_location("original_fleet", TOOL)
COMPILER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COMPILER)


def spec(identifier="SH001", flyable=True):
    result = {
        "id": identifier, "name": "Original " + identifier, "family": "new-family",
        "role": "trader", "license": "MIT", "playerFlyable": flyable,
        "purchasePolicy": "blueprintFabrication" if flyable else "never",
        "balance": {"method": "Independent fixture budget", "sourceProfilesIncluded": False},
    }
    if flyable:
        result["game"] = {
            "cargo": 63, "speed": 34.8, "acceleration": 9.6, "energy": 270,
            "recharge": 3.78, "roll": 0.88, "pitch": 0.77, "yaw": 0.72,
            "shield": 240, "shieldRecharge": 1.5, "fuel": 130, "jump": 9,
            "spool": 12, "missiles": 5, "facings": 15, "cargoExpansion": 25, "price": 216000,
        }
    else:
        result["display"] = {"purchasable": False, "specification": "Structural object"}
    return result


def hull(identity):
    design = {
        "vertices": [[0.0, 0.0, -0.0], [1.25, 0.0, 0.0], [0.0, 2.5, 0.0], [0.0, 0.0, 3.75]],
        "faces": [[0, 2, 1], [0, 1, 3], [0, 3, 2], [1, 2, 3]],
        "license": "MIT", "source": "Original fixture geometry, no imported model",
        "materials": [{"name": "original", "colour": 0xFFFFFFFF, "emissive": False}],
        "faceMaterials": [0, 0, 0, 0],
        "textures": [{"asset": "original-test", "license": "MIT", "repeat": True}],
        "faceTextures": [{"texture": 0, "uv": [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0]]} for _ in range(4)],
    }
    return {"proposal": {key: identity[key] for key in ("id", "name", "family")},
            "design": design, "nativeDesign": copy.deepcopy(design)}


def write_toml(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("# Immutable test fixture\n" + "\n".join(
        json.dumps(key) + " = " + COMPILER.toml_value(value) for key, value in data.items()
    ) + "\n")


class OriginalFleetTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "proposal"
        self.output = self.root / "staging"
        self.ship = spec()
        self.geometry = hull(self.ship)
        write_toml(self.source / "fleet-specs/SH001.toml", self.ship)
        write_toml(self.source / "fleet-specs/SH002.toml", spec("SH002", False))
        write_toml(self.source / "replacement-hulls/SH001-design.toml", self.geometry)

    def compile(self, output=None):
        return COMPILER.compile_fleet(self.source, output or self.output, 2, 1)

    def test_exact_original_data_join_and_missing_mesh_preservation(self):
        manifest = self.compile()
        joined = tomllib.loads((self.output / "joined/SH001.toml").read_text())
        self.assertEqual({k: joined[k] for k in self.ship}, self.ship)
        self.assertEqual(joined["design"], self.geometry["design"])
        for key in ("nativeDesign", "nativeHull", "nativeCombat", "profiles"):
            self.assertNotIn(key, joined)
        self.assertEqual((self.output / "specs/SH001.toml").read_bytes(), (self.source / "fleet-specs/SH001.toml").read_bytes())
        self.assertEqual((self.output / "original-hulls/SH001-design.toml").read_bytes(), (self.source / "replacement-hulls/SH001-design.toml").read_bytes())
        self.assertFalse((self.output / "joined/SH002.toml").exists())
        missing = manifest["ships"][1]
        self.assertIn("approved-original-mesh-missing", missing["dependencies"])
        self.assertFalse(missing["playerFlyableAuthored"])
        self.assertNotIn("game", tomllib.loads((self.output / missing["spec"]).read_text()))
        self.assertEqual(manifest["ships"][0]["unsupportedDesignFields"], ["faceTextures", "textures"])
        self.assertEqual(manifest["ships"][0]["textureAssetsNotSupplied"], ["original-test"])
        self.assertIn("original-cargo-and-accommodation-contract", manifest["ships"][0]["dependencies"])
        self.assertFalse(manifest["ships"][0]["currentLoaderCompatible"])
        self.assertNotIn("readiness.json", [item["path"] for item in manifest["files"]])

    def test_deterministic_generation_and_check_mode(self):
        first = self.compile()
        second_output = self.root / "second"
        second = self.compile(second_output)
        self.assertEqual(first, second)
        for path in self.output.rglob("*"):
            if path.is_file():
                self.assertEqual(path.read_bytes(), (second_output / path.relative_to(self.output)).read_bytes())
        stamps = {p: p.stat().st_mtime_ns for p in self.output.rglob("*") if p.is_file()}
        self.assertEqual(COMPILER.check_staging(self.output), first)
        self.assertEqual({p: p.stat().st_mtime_ns for p in stamps}, stamps)
        with self.assertRaisesRegex(ValueError, "fresh/empty"):
            self.compile()

    def test_zero_price_requires_never_policy_and_keeps_other_bounds(self):
        for policy in ("never", "blueprintFabrication", "pendingFabrication", "xyzzyOnly", "unknown"):
            for price in (-1, 0, 1, 100000000, 100000001, True):
                with self.subTest(policy=policy, price=price):
                    game = copy.deepcopy(self.ship["game"])
                    game["price"] = price
                    issues = COMPILER.game_issues(game, policy)
                    expected = type(price) is not int or not (0 if policy == "never" else 1) <= price <= 100000000
                    self.assertEqual(any("game.price:" in issue for issue in issues), expected)
        game = copy.deepcopy(self.ship["game"])
        game["price"] = 0
        self.assertTrue(any("game.price:" in issue for issue in COMPILER.game_issues(game)))

    def test_unpriced_never_staging_preserves_raw_zero_and_capability_conflicts(self):
        self.ship["purchasePolicy"] = "never"
        for key in ("price", "jump", "spool", "fuel", "missiles", "facings"):
            self.ship["game"][key] = 0
        source = self.source / "fleet-specs/SH001.toml"
        write_toml(source, self.ship)
        original = source.read_bytes()
        manifest = self.compile()
        entry = manifest["ships"][0]
        issues = entry["gameValidityIssues"]
        self.assertFalse(any("game.price:" in issue for issue in issues))
        for key in ("jump", "spool", "fuel", "missiles", "facings"):
            self.assertTrue(any("game." + key + ":" in issue for issue in issues))
        self.assertEqual((self.output / entry["spec"]).read_bytes(), original)
        joined = tomllib.loads((self.output / entry["joined"]).read_text())
        self.assertEqual(joined["game"], self.ship["game"])
        self.assertFalse(entry["runtimeReady"])

    def test_policy_zeros_and_unknown_fields_retained_without_fixes(self):
        self.ship["purchasePolicy"] = "plughQuestFabrication"
        self.ship["game"]["price"] = 0
        self.ship["game"]["futureAuthoredQuantity"] = 123.75
        self.ship["access"] = "quest-gated"
        write_toml(self.source / "fleet-specs/SH001.toml", self.ship)
        manifest = self.compile()
        entry = manifest["ships"][0]
        self.assertEqual(entry["purchasePolicyAuthored"], "plughQuestFabrication")
        self.assertIn("unsupported-purchase-policy", entry["dependencies"])
        self.assertIn("access", entry["unsupportedSpecFields"])
        self.assertTrue(any("game.price" in issue for issue in entry["gameValidityIssues"]))
        self.assertTrue(any("futureAuthoredQuantity" in issue for issue in entry["gameValidityIssues"]))
        joined = tomllib.loads((self.output / entry["joined"]).read_text())
        self.assertEqual(joined["game"], self.ship["game"])
        self.assertEqual(joined["access"], "quest-gated")

    def test_identity_mismatch_and_legacy_attachment_fail_explicitly(self):
        for change in ("id", "legacy"):
            with self.subTest(change=change):
                geometry = copy.deepcopy(self.geometry)
                if change == "legacy":
                    geometry["nativeCombat"] = {"energy": 256}
                else:
                    geometry["proposal"][change] = "wrong"
                write_toml(self.source / "replacement-hulls/SH001-design.toml", geometry)
                with self.assertRaises(ValueError):
                    self.compile(self.root / change)
        geometry = copy.deepcopy(self.geometry)
        geometry["proposal"]["family"] = "other-authored-family"
        write_toml(self.source / "replacement-hulls/SH001-design.toml", geometry)
        manifest = self.compile(self.root / "family-difference")
        entry = manifest["ships"][0]
        self.assertEqual(entry["hullSpecMetadataDifferences"], [{"field": "family", "spec": "new-family", "hullProposal": "other-authored-family"}])
        self.assertIn("hull-spec-metadata-difference", entry["dependencies"])
        self.assertEqual(tomllib.loads((self.root / "family-difference" / entry["joined"]).read_text())["family"], "new-family")
        self.ship["profiles"] = []
        write_toml(self.source / "fleet-specs/SH001.toml", self.ship)
        with self.assertRaisesRegex(ValueError, "Legacy/geometry"):
            self.compile(self.root / "profiles")

    def test_bad_geometry_material_uv_and_nonfinite_rejected(self):
        for change in ("face", "vertex", "material", "uv"):
            with self.subTest(change=change):
                design = copy.deepcopy(self.geometry["design"])
                if change == "face":
                    design["faces"][0][0] = 999
                elif change == "vertex":
                    design["vertices"][0][0] = float("inf")
                elif change == "material":
                    design["materials"][0]["colour"] = 0xFFFFFF00
                else:
                    design["faceTextures"][0]["uv"].pop()
                with self.assertRaises(ValueError):
                    COMPILER.validate_design(design, "fixture")
        design = copy.deepcopy(self.geometry["design"])
        design["textures"] = []
        for mapping in design["faceTextures"]:
            mapping["texture"] = -1
            mapping["uv"] = [[0.0, 0.0]] * 3
        self.assertEqual(COMPILER.validate_design(design, "untextured")["untexturedCornerUVs"], 4)

    def test_missing_or_mismatched_spec_filename_fails_before_writes(self):
        write_toml(self.source / "fleet-specs/SH002.toml", spec("SH003"))
        with self.assertRaisesRegex(ValueError, "filename/ID"):
            self.compile()
        self.assertFalse(self.output.exists())
        with self.assertRaisesRegex(ValueError, "Expected"):
            COMPILER.compile_fleet(self.source, self.output, 171, 94)

    def test_check_detects_corruption_extra_files_and_traversal(self):
        manifest = self.compile()
        path = self.output / "specs/SH001.toml"
        raw = path.read_bytes()
        path.write_bytes(raw.replace(b"216000", b"999999"))
        with self.assertRaisesRegex(ValueError, "corrupt"):
            COMPILER.check_staging(self.output)
        path.write_bytes(raw)
        extra = self.output / "unexpected.toml"
        extra.write_text("extra")
        with self.assertRaisesRegex(ValueError, "Unexpected/missing"):
            COMPILER.check_staging(self.output)
        extra.unlink()
        manifest["files"][0]["path"] = "../../outside"
        (self.output / "readiness.json").write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            COMPILER.check_staging(self.output)

    def test_input_symlink_overlap_and_output_budget_rejected(self):
        with self.assertRaisesRegex(ValueError, "overlap"):
            COMPILER.compile_fleet(self.source, self.source / "output", 2, 1)
        path = self.source / "fleet-specs/SH001.toml"
        other = self.root / "elsewhere.toml"
        other.write_bytes(path.read_bytes())
        path.unlink()
        path.symlink_to(other)
        with self.assertRaises(ValueError):
            self.compile()
        sink = COMPILER.Artifacts(self.root / "budget")
        sink.total = COMPILER.MAX_OUTPUT_BYTES
        with self.assertRaisesRegex(ValueError, "500 MiB"):
            sink.emit("small.txt", [b"x"])

    def test_toml_escaping_and_cli_missing_input(self):
        value = 'Original "quoted" \\ hull\n\t' + chr(0x1F680)
        self.assertEqual(tomllib.loads("value = " + COMPILER.toml_value(value))["value"], value)
        output = io.StringIO()
        with contextlib.redirect_stderr(output):
            status = COMPILER.main(["--output-root", str(self.output)])
        self.assertEqual(status, 2)
        self.assertIn("--input-root is required", output.getvalue())
        self.assertFalse(self.output.exists())

    def test_escaped_source_del_and_controls_round_trip_through_real_join(self):
        value = 'Original "quoted" \\ ' + "".join(chr(i) for i in range(32)) + chr(127) + chr(0x1F680)
        geometry = copy.deepcopy(self.geometry)
        geometry["design"]["source"] = value
        geometry["design"]["extra" + chr(127)] = {"note" + chr(127): value}
        path = self.source / "replacement-hulls/SH001-design.toml"
        write_toml(path, geometry)
        # The source remains legal TOML even with the pre-fix encoder; exercise the joined writer.
        raw = path.read_text().replace(chr(127), "\\u007f")
        path.write_text(raw)
        self.assertEqual(tomllib.loads(raw)["design"]["source"], value)
        manifest = self.compile()
        joined_raw = (self.output / manifest["ships"][0]["joined"]).read_text()
        joined = tomllib.loads(joined_raw)
        self.assertEqual(joined["design"], geometry["design"])
        self.assertNotIn(chr(127), joined_raw)
        self.assertIn("\\u007f", joined_raw)

    def test_explicit_output_root_symlink_refused_without_destination_writes(self):
        destination = self.root / "empty-destination"
        destination.mkdir()
        link = self.root / "output-link"
        link.symlink_to(destination, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "Symlink output root"):
            self.compile(link)
        with self.assertRaisesRegex(ValueError, "Symlink output root"):
            COMPILER.Artifacts(link)
        with self.assertRaisesRegex(ValueError, "Symlink output root"):
            COMPILER.check_staging(link)
        self.assertEqual(list(destination.iterdir()), [])
        self.assertTrue(link.is_symlink())


class IndexedFleetTests(unittest.TestCase):
    def setUp(self):
        OriginalFleetTests.setUp(self)
        self.index_path = Path("delivery-index.json")
        self.selected = copy.deepcopy(self.geometry)
        self.selected["nativeDesign"]["vertices"][3][2] = 4.25
        self.effective = "completion/native-lod/SH001-design.toml"
        write_toml(self.source / self.effective, self.selected)
        second = hull(spec("SH002", False))
        write_toml(self.source / "completion/SH002-design.toml", second)
        self.index = {"schema": "l337.complete-original-fleet-index/1",
                      "workspace": "/old/author/machine/not/a/path/authority", "ships": []}
        for identifier, geometry in (("SH001", self.effective), ("SH002", "completion/SH002-design.toml")):
            stats = f"fleet-specs/{identifier}.toml"
            self.index["ships"].append({"id": identifier, "statsFile": stats,
                                        "statsSHA256": COMPILER.digest((self.source / stats).read_bytes()),
                                        "geometryFile": geometry,
                                        "geometrySHA256": COMPILER.digest((self.source / geometry).read_bytes())})
        self.write_index()

    def write_index(self):
        (self.source / self.index_path).write_text(json.dumps(self.index))

    def compile(self, output=None):
        return COMPILER.compile_fleet(self.source, output or self.output, 2, 2, self.index_path)

    def test_effective_lod_exact_source_provenance_and_no_runtime_claim(self):
        manifest = self.compile()
        self.assertEqual(manifest["counts"]["missingMeshes"], 0)
        self.assertEqual(manifest["counts"]["hulls"], 2)
        self.assertFalse(manifest["runtimeReady"])
        entry = manifest["ships"][0]
        self.assertEqual(entry["sources"][1]["path"], self.effective)
        self.assertEqual(entry["sources"][1]["sha256"], self.index["ships"][0]["geometrySHA256"])
        self.assertEqual((self.output / entry["hull"]).read_bytes(), (self.source / self.effective).read_bytes())
        staged = tomllib.loads((self.output / entry["hull"]).read_text())
        self.assertEqual(staged["nativeDesign"], self.selected["nativeDesign"])
        self.assertNotEqual(staged["nativeDesign"], self.geometry["nativeDesign"])
        joined = tomllib.loads((self.output / entry["joined"]).read_text())
        self.assertEqual(joined["design"], self.selected["design"])
        self.assertEqual({key: joined[key] for key in self.ship}, self.ship)
        self.assertEqual(manifest["deliveryIndex"]["sha256"], COMPILER.digest((self.source / self.index_path).read_bytes()))

    def test_stale_spec_or_geometry_fingerprint_refuses(self):
        for index, field in enumerate(("statsFile", "geometryFile")):
            path = self.source / self.index["ships"][0][field]
            original = path.read_bytes()
            path.write_bytes(original + b"\n# changed since approval\n")
            with self.assertRaisesRegex(ValueError, "fingerprint mismatch"):
                self.compile(self.root / f"stale-{index}")
            path.write_bytes(original)

    def test_missing_duplicate_extra_and_contradictory_identity_refuse(self):
        original = copy.deepcopy(self.index)
        variations = []
        missing = copy.deepcopy(original); missing["ships"].pop(); variations.append(missing)
        duplicate = copy.deepcopy(original); duplicate["ships"][1] = duplicate["ships"][0]; variations.append(duplicate)
        extra = copy.deepcopy(original); extra["ships"].append(extra["ships"][0]); variations.append(extra)
        wrong = copy.deepcopy(original); wrong["ships"][0]["statsFile"] = "fleet-specs/SH002.toml"; variations.append(wrong)
        unknown = copy.deepcopy(original); unknown["schema"] = "unrecognized"; variations.append(unknown)
        for number, self.index in enumerate(variations):
            self.write_index()
            with self.assertRaises(ValueError):
                self.compile(self.root / f"identity-{number}")
        self.index = original
        self.index["ships"][0]["geometrySHA256"] = "not-a-sha"
        self.write_index()
        with self.assertRaisesRegex(ValueError, "fingerprint"):
            self.compile(self.root / "invalid-sha")

    def test_escaping_and_symlink_indexed_inputs_refuse(self):
        original = copy.deepcopy(self.index)
        for number, name in enumerate(("../SH001-design.toml", "/outside/SH001-design.toml")):
            self.index["ships"][0]["geometryFile"] = name
            self.write_index()
            with self.assertRaises(ValueError):
                self.compile(self.root / f"escape-{number}")
        self.index = original
        self.write_index()
        path = self.source / self.effective
        destination = self.root / "outside.toml"
        destination.write_bytes(path.read_bytes())
        path.unlink()
        path.symlink_to(destination)
        with self.assertRaisesRegex(ValueError, "escapes root|Symlink"):
            self.compile(self.root / "symlink-input")
        link = self.source / "index-link.json"
        link.symlink_to(self.source / self.index_path)
        with self.assertRaisesRegex(ValueError, "Symlink"):
            COMPILER.compile_fleet(self.source, self.root / "symlink-index", 2, 2, Path("index-link.json"))

    def test_deterministic_indexed_staging_and_frozen_check(self):
        first = self.compile()
        second = self.compile(self.root / "second")
        self.assertEqual(first, second)
        self.assertEqual(COMPILER.check_staging(self.output), first)


if __name__ == "__main__":
    unittest.main()
