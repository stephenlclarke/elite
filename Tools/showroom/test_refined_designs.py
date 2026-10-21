"""Visual revisions must preserve authoritative gameplay and imported blueprints."""

import copy
import hashlib
import importlib.util
import json
import math
import unittest
from pathlib import Path


def load(name):
    spec = importlib.util.spec_from_file_location(
        name, Path(__file__).with_name(name + ".py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


files = load("ship-files")
refine = load("refine-catalogue")
author = load("refined-designs")


def digest(value):
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


class RefinedDesignTests(unittest.TestCase):
    def assert_original_peregrine(self, ship):
        # Approved F01 replaces this one historical recipe and its predecessor profile.
        self.assertEqual(ship["id"], "SH025")
        self.assertEqual(ship["name"], "Peregrine Mk V")
        self.assertEqual(ship["catalogue"]["family"], "peregrine")
        self.assertEqual([profile["id"] for profile in ship["profiles"]], ["L337-PLAYER-SH025"])
        self.assertEqual((ship["game"]["cargo"], ship["game"]["cargoExpansion"]), (92, 35))
        self.assertNotIn("recipe", ship["design"])
        self.assertEqual(
            hashlib.sha256((files.SHIP_FOLDER / "SH025.toml").read_bytes()).hexdigest(),
            "794c19f74e633c5837ad78705398cf74f349b1ca4854b22bb3257d23bcb4059a",
        )

    def test_verified_untextured_revision_removes_obsolete_texture_facts(self):
        ship = copy.deepcopy(next(s for s in files.read_ships() if s["id"] == "SH022"))
        self.assertTrue(ship["design"]["sourceTextures"])
        incoming = {
            key: copy.deepcopy(ship["design"][key])
            for key in ["vertices", "faces", "sourceFaceColours"]
        }
        refine.source_appearance(ship, incoming)
        self.assertNotIn("sourceTextures", ship["design"])
        self.assertNotIn("sourceFaceTextures", ship["design"])
        self.assertEqual(
            ship["design"]["sourceFaceColours"], incoming["sourceFaceColours"]
        )
        incoming["vertices"][0][0] += 1
        with self.assertRaises(AssertionError):
            refine.source_appearance(ship, incoming)

    def test_game_profiles_ids_native_blueprints_and_imported_geometry_are_preserved(
        self,
    ):
        baseline = json.loads(
            Path("Tests/Fixtures/ship-visual-revision-baseline.json").read_text()
        )["ships"]
        ships = {s["id"]: s for s in files.read_ships()}
        deltas = json.loads(Path("Tests/Fixtures/ship-catalogue-balance-baseline-deltas.json").read_text())["ships"]
        balance = {row["id"]: row for row in json.loads(Path("docs/research/data/ship-catalogue-balance.json").read_text())["ships"]}
        self.assertTrue(set(baseline).issubset(ships))
        old_cabin_basis = (
            "Zero fitted charter berths; operating quarters are outside usable cargo. "
            "Berths require 5t plus one equipment unit each."
        )
        new_cabin_basis = (
            "Zero fitted charter berths; operating quarters are outside usable cargo. "
            "Cabin modules require 5t plus one equipment unit each, independent of "
            "grade or occupied places."
        )

        def restore_reviewed_cabin_basis(value, delta, ident):
            profile = next(
                (p for p in value["profiles"] if p["id"] == "PROJECT-PLAYER-" + ident),
                None,
            )
            if profile is None:
                return 0
            fields = {field["key"]: field for field in profile["fields"]}
            if "fitted_passenger_berths" not in fields:
                return 0
            keys = [
                "fitted_passenger_berths",
                "passengers_aboard",
                "free_passenger_places",
                "hold_used_by_cabins",
            ]
            # Balanced hold fields retain their separate exact afterSHA256 below.
            if not any(c["key"] == "usable_cargo_after_fit" for c in delta.get("fields", [])):
                keys.append("usable_cargo_after_fit")
            for key in keys:
                self.assertEqual(fields[key]["basis"], new_cabin_basis, (ident, key))
                fields[key]["basis"] = old_cabin_basis
            return len(keys)

        def assert_original_record(value, record, ident):
            self.assertEqual(digest(value), record["unchangedRecord"], ident)

        source_count = 0
        cabin_ships = 0
        cabin_fields = 0
        for ident, record in baseline.items():
            ship = ships[ident]
            if ident == "SH025":
                self.assert_original_peregrine(ship)
                self.assertIsNone(record["sourceGeometry"])
                continue
            preserved = copy.deepcopy({k: v for k, v in ship.items() if k != "design"})
            self.assertEqual(preserved.pop("catalogue"), balance[ident]["catalogue"], ident)
            # Reverse only the reviewed project balance delta, keeping the original
            # whole-record and imported geometry pins below fully authoritative.
            delta = deltas.get(ident, {})
            if ident == "SH001":
                wrong_wording = copy.deepcopy(preserved)
                profile = next(
                    p for p in wrong_wording["profiles"] if p["id"] == "PROJECT-PLAYER-SH001"
                )
                field = next(f for f in profile["fields"] if f["key"] == "fitted_passenger_berths")
                field["basis"] += " changed"
                with self.assertRaises(AssertionError):
                    restore_reviewed_cabin_basis(wrong_wording, delta, ident)
            restored = restore_reviewed_cabin_basis(preserved, delta, ident)
            cabin_ships += int(restored > 0)
            cabin_fields += restored
            if "name" in delta:
                self.assertEqual(preserved["name"], delta["name"]["after"], ident)
                preserved["name"] = delta["name"]["before"]
            if "cargo" in delta:
                self.assertEqual(preserved["game"]["cargo"], delta["cargo"]["after"], ident)
                preserved["game"]["cargo"] = delta["cargo"]["before"]
            for change in delta.get("fields", []):
                profile = next(p for p in preserved["profiles"] if p["id"] == change["profile"])
                index = next(i for i, f in enumerate(profile["fields"]) if f["key"] == change["key"])
                self.assertEqual(digest(profile["fields"][index]), change["afterSHA256"], ident)
                if change["before"] is None:
                    profile["fields"].pop(index)
                else:
                    profile["fields"][index] = copy.deepcopy(change["before"])
            if ident == "SH023":
                # Independent utility fittings were added after this visual baseline.
                # Check that addition exactly while keeping every original field pinned.
                self.assertEqual(
                    preserved["game"].pop("workTools", None),
                    ["miningLaser", "salvageCutter"],
                    ident,
                )
            if ident == "SH128":
                # Approved 8ebb582 changes only the player hold and two current
                # refit fields. Reverse that exact delta to retain the old pin.
                self.assertEqual(preserved["game"]["cargo"], 12, ident)
                preserved["game"]["cargo"] = 0
                profile = next(
                    p for p in preserved["profiles"] if p["id"] == "PROJECT-PLAYER-SH128"
                )
                fields = {f["key"]: f for f in profile["fields"]}
                borrowed = (
                    "Pinned O08 oolite_template_transporter max_cargo12; replaces prior "
                    "volume-based zero estimate, not a claim that Transporter was "
                    "originally a flyable Oolite ship."
                )
                for key, old_status, old_basis in [
                    ("cargo_tonnes", "estimated", "O08 model envelope"),
                    (
                        "usable_cargo_after_fit",
                        "standard unladen refit",
                        "Zero fitted charter berths; operating quarters are outside usable "
                        "cargo. Berths require 5t plus one equipment unit each.",
                    ),
                ]:
                    field = fields[key]
                    basis = borrowed
                    if key == "usable_cargo_after_fit":
                        basis += " Unladen common fit has no fitted cabin deduction."
                    self.assertEqual(
                        {k: field[k] for k in ["text", "number", "status", "basis"]},
                        {
                            "text": "12 t",
                            "number": 12,
                            "status": "borrowed native NPC capacity for player adaptation",
                            "basis": basis,
                        },
                        ident,
                    )
                    field.update(text="0 t", number=0, status=old_status, basis=old_basis)
            assert_original_record(preserved, record, ident)
            if ident == "SH001":
                changed_game = copy.deepcopy(preserved)
                changed_game["game"]["cargo"] += 1
                with self.assertRaises(AssertionError):
                    assert_original_record(changed_game, record, ident)
                changed_number = copy.deepcopy(preserved)
                profile = next(
                    p for p in changed_number["profiles"] if p["id"] == "PROJECT-PLAYER-SH001"
                )
                field = next(f for f in profile["fields"] if f["key"] == "fitted_passenger_berths")
                field["number"] += 1
                with self.assertRaises(AssertionError):
                    assert_original_record(changed_number, record, ident)
            if record["sourceGeometry"]:
                d = ship["design"]
                self.assertEqual(
                    digest(
                        {
                            k: d[k]
                            for k in [
                                "vertices",
                                "faces",
                                "license",
                                "source",
                                "custody",
                            ]
                        }
                    ),
                    record["sourceGeometry"],
                    ident,
                )
                source_count += 1
        self.assertEqual(source_count, 74)
        self.assertEqual(cabin_ships, 157)
        self.assertEqual(cabin_fields, 731)

    def test_each_recipe_regenerates_complete_materials_and_real_detail_with_valid_faces(
        self,
    ):
        count = 0
        ships = files.read_ships()
        self.assertEqual(sum(ship["id"] == "SH025" for ship in ships), 1)
        self.assert_original_peregrine(next(ship for ship in ships if ship["id"] == "SH025"))
        for ship in ships:
            d = ship["design"]
            recipe = d.get("recipe", {})
            self.assertEqual(len(d["faceMaterials"]), len(d["faces"]), ship["id"])
            self.assertTrue(d.get("paletteName") or ship["id"] == "SH171")
            if recipe.get("revision") != 2 or recipe.get("family") == "liberator-dsv2":
                continue
            count += 1
            self.assertEqual({**author.design(recipe), "recipe": recipe}, d, ship["id"])
            self.assertLess(len(d["faces"]), 6000)
            self.assertEqual(
                sum(c["faceCount"] for c in d["components"]), len(d["faces"])
            )
            if recipe["detailStyle"] == "armour":
                self.assertTrue(
                    any(c["name"] == "vent grille" for c in d["components"]), ship["id"]
                )
            if recipe["detailStyle"] == "organic":
                self.assertFalse(any("grille" in c["name"] for c in d["components"]))
            for face in d["faces"]:
                a, b, c = [d["vertices"][i] for i in face[:3]]
                ab, ac = (
                    [b[i] - a[i] for i in range(3)],
                    [c[i] - a[i] for i in range(3)],
                )
                n = [
                    ab[1] * ac[2] - ab[2] * ac[1],
                    ab[2] * ac[0] - ab[0] * ac[2],
                    ab[0] * ac[1] - ab[1] * ac[0],
                ]
                length = math.sqrt(sum(x * x for x in n))
                self.assertGreater(length, 1e-6, ship["id"])
                for i in face[3:]:
                    p = d["vertices"][i]
                    self.assertLess(
                        abs(sum(n[k] * (p[k] - a[k]) for k in range(3))) / length,
                        1e-4,
                        ship["id"],
                    )
        self.assertEqual(count, 92)


if __name__ == "__main__":
    unittest.main()
