"""Source-only regression cases for one reviewed project overlay across authoring paths."""

import copy
import importlib.util
import unittest
import tempfile
import tomllib
from pathlib import Path

_spec = importlib.util.spec_from_file_location("catalogue_balance", Path(__file__).with_name("catalogue-balance.py"))
balance = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(balance)


class CatalogueBalanceTests(unittest.TestCase):
    def fixture(self):
        fields = [{"key": "cargo_tonnes", "number": 10, "text": "10 t", "unit": "t", "status": "borrowed", "basis": "source"},
                  {"key": "cargo_expansion_tonnes", "number": 0, "text": "0 t", "unit": "t", "status": "choice", "basis": "source"},
                  {"key": "usable_cargo_after_fit", "number": 10, "text": "10 t", "unit": "t", "status": "standard", "basis": "source"},
                  {"key": "hold_used_by_cabins", "number": 0, "text": "0 t", "unit": "t"},
                  {"key": "required_crew_including_commander", "number": 8}]
        ship = {"id": "SH100", "game": {"cargo": 10, "cargoExpansion": 15, "speed": 29.257},
                "design": {"vertices": [[1, 2, 3]], "source": "unchanged"},
                "profiles": [{"group": "project-refit-v1", "fields": fields},
                             {"group": "oolite-npc", "fields": copy.deepcopy(fields)}]}
        rows = {"SH100": {"catalogue": {"schemaVersion": 1, "family": "Python"},
                          "game": {"cargo": 150, "cargoExpansion": 15}, "cargoBasis": "Reviewed project balance"}}
        return ship, rows

    def test_effective_cargo_overlay_preserves_archives_geometry_and_other_performance(self):
        ship, rows = self.fixture()
        original = copy.deepcopy(ship)
        selected = balance.apply_balance(ship, rows)
        self.assertEqual(ship, original)
        self.assertEqual(selected["game"], {"cargo": 150, "cargoExpansion": 15, "speed": 29.257})
        self.assertEqual(selected["design"], original["design"])
        self.assertEqual(selected["profiles"][1], original["profiles"][1])
        self.assertEqual(selected["profiles"][0]["fields"][-1], original["profiles"][0]["fields"][-1])
        self.assertEqual([f["number"] for f in selected["profiles"][0]["fields"][:3]], [150, 15, 150])
        self.assertEqual(balance.apply_balance(selected, rows), selected)
        balance.require_consistent(selected, rows)
        with self.assertRaises(ValueError):
            balance.require_consistent(original, rows)

    def test_retained_cabin_hold_and_crew_are_not_deleted_to_advertise_more_cargo(self):
        ship, rows = self.fixture()
        fields = ship["profiles"][0]["fields"]
        next(field for field in fields if field["key"] == "hold_used_by_cabins")["number"] = 5
        selected = balance.apply_balance(ship, rows)
        after = {field["key"]: field for field in selected["profiles"][0]["fields"]}
        self.assertEqual(after["hold_used_by_cabins"]["number"], 5)
        self.assertEqual(after["usable_cargo_after_fit"]["number"], 145)
        self.assertEqual(after["required_crew_including_commander"]["number"], 8)
        self.assertEqual(selected["profiles"][1], ship["profiles"][1])

    def test_staged_import_and_direct_writer_use_identical_project_fields(self):
        ship, rows = self.fixture()
        direct = balance.apply_balance(ship, rows)
        staged = copy.deepcopy(ship)
        staged.pop("game")
        imported = balance.apply_record_balance(staged, rows)
        self.assertEqual(imported["catalogue"], direct["catalogue"])
        self.assertEqual(imported["profiles"], direct["profiles"])
        self.assertNotIn("game", imported)

    def test_capacity_reduction_and_invented_missing_mechanics_are_rejected(self):
        ship, rows = self.fixture()
        rows["SH100"]["game"]["cargo"] = 9
        with self.assertRaises(ValueError):
            balance.apply_balance(ship, rows)
        ship.pop("game")
        with self.assertRaises(ValueError):
            balance.apply_balance(ship, rows)

    def test_all_authored_tomls_match_the_reviewed_input(self):
        files_spec = importlib.util.spec_from_file_location("ship_files", Path(__file__).with_name("ship-files.py"))
        files = importlib.util.module_from_spec(files_spec)
        files_spec.loader.exec_module(files)
        rows = balance.load_balances()
        ships = files.read_ships()
        self.assertEqual({s["id"] for s in ships}, set(rows))
        for ship in ships:
            balance.require_consistent(ship, rows)
            row = rows[ship["id"]]
            if "game" in ship:
                self.assertGreaterEqual(ship["game"]["cargo"], row["originalGame"]["cargo"])
                if ship["id"] == "SH025":
                    # F01 replaces the historical profile; keep its archive independently intact.
                    self.assertEqual(ship["name"], "Peregrine Mk V")
                    self.assertEqual(ship["catalogue"]["family"], "peregrine")
                    self.assertEqual([profile["id"] for profile in ship["profiles"]], ["L337-PLAYER-SH025"])
                    self.assertEqual(row["originalGame"], {"cargo": 12, "cargoExpansion": 0})
                    self.assertEqual(row["game"], {"cargo": 92, "cargoExpansion": 35})
                    self.assertEqual({key: ship["game"][key] for key in row["game"]}, row["game"])
                else:
                    self.assertEqual(ship["game"]["cargoExpansion"], row["originalGame"]["cargoExpansion"])
            # Overlay idempotence preserves unrelated authored fields.
            self.assertEqual(balance.apply_balance(ship, rows), ship)

    def test_shared_refinement_and_liberator_writer_keeps_reviewed_values(self):
        files_spec = importlib.util.spec_from_file_location("ship_files", Path(__file__).with_name("ship-files.py"))
        files = importlib.util.module_from_spec(files_spec)
        files_spec.loader.exec_module(files)
        ships = {s["id"]: s for s in files.read_ships()}
        with tempfile.TemporaryDirectory() as directory:
            for identity in ["SH100", "SH171", "SH153", "SH028"]:
                ship = ships[identity]
                output = Path(directory) / (identity + ".toml")
                files.write_ship(output, ship)
                regenerated = tomllib.loads(output.read_text())
                self.assertEqual(regenerated, ship)
                staged = copy.deepcopy(ship)
                staged.pop("game", None)
                projected = balance.apply_record_balance(staged, balance.load_balances())
                self.assertEqual(projected["profiles"], regenerated["profiles"])
                self.assertEqual(projected["catalogue"], regenerated["catalogue"])


if __name__ == "__main__":
    unittest.main()
