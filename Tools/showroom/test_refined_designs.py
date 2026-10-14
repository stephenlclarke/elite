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
        self.assertTrue(set(baseline).issubset(ships))
        source_count = 0
        for ident, record in baseline.items():
            ship = ships[ident]
            self.assertEqual(
                digest({k: v for k, v in ship.items() if k != "design"}),
                record["unchangedRecord"],
                ident,
            )
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

    def test_each_recipe_regenerates_complete_materials_and_real_detail_with_valid_faces(
        self,
    ):
        count = 0
        for ship in files.read_ships():
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
        self.assertEqual(count, 93)


if __name__ == "__main__":
    unittest.main()
