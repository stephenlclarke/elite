"""Apply reviewed catalogue metadata and effective project cargo without altering archives."""

import copy
import json
from pathlib import Path

BALANCE_FILE = Path("docs/research/data/ship-catalogue-balance.json")
PROJECT_GROUPS = {"project-refit-v1", "liberator-native-v1"}
CARGO_FIELDS = {
    "cargo_tonnes": "cargo",
    "cargo": "cargo",
    "cargo_expansion_tonnes": "cargoExpansion",
    "cargoExpansion": "cargoExpansion",
    "usable_cargo_after_fit": "cargo",
}


def load_balances(path=BALANCE_FILE):
    """Require a single stable-ID record rather than silent duplicate overrides."""
    document = json.loads(path.read_text())
    if document.get("schemaVersion") != 1 or document.get("metadataSchemaVersion") != 2:
        raise ValueError("Unsupported catalogue balance schema")
    records = {}
    for row in document["ships"]:
        identity = row["id"]
        if identity in records:
            raise ValueError("Duplicate catalogue balance: " + identity)
        records[identity] = row
    return records


def apply_balance(ship, balances):
    """Overlay project fields only; copy inputs so authoring has no hidden mutation."""
    result = copy.deepcopy(ship)
    row = balances[ship["id"]]
    result["catalogue"] = copy.deepcopy(row["catalogue"])
    if row.get("displayName") is not None:
        result["name"] = row["displayName"]
    selected = row.get("game")
    if "game" in result:
        if selected is None or set(selected) != {"cargo", "cargoExpansion"}:
            raise ValueError("Missing effective cargo balance: " + ship["id"])
        for key, value in selected.items():
            if type(value) is not int or not 0 <= value <= 100000:
                raise ValueError("Invalid effective cargo: " + ship["id"])
            if value < result["game"][key]:
                raise ValueError("Cargo balance cannot reduce existing capacity: " + ship["id"])
            result["game"][key] = value
    elif selected is not None:
        # Missing native mechanics is explicit queued integration work, never a fabricated grant.
        raise ValueError("Cargo override has no actual game mechanics: " + ship["id"])
    _update_project_fields(result, row)
    return result


def apply_record_balance(record, balances):
    """Project the same overlay into staged research records without inventing a game table."""
    result = copy.deepcopy(record)
    row = balances[record["id"]]
    result["catalogue"] = copy.deepcopy(row["catalogue"])
    if row.get("displayName") is not None:
        result["name"] = row["displayName"]
    _update_project_fields(result, row)
    return result


def _update_project_fields(result, row):
    """Keep one effective profile projection for direct and staged authoring."""
    selected = row.get("game")
    for profile in result["profiles"]:
        if profile["group"] not in PROJECT_GROUPS or selected is None:
            continue
        keys = {field["key"] for field in profile["fields"]}
        if profile["group"] == "project-refit-v1":
            if "hold_used_by_cabins" not in keys:
                initial = next((field["number"] for field in profile["fields"]
                                if field["key"] == "initial_charter_passenger_berths"), None)
                if type(initial) is not int or not 0 <= initial <= 10000:
                    raise ValueError("Missing retained standard cabin fit: " + result["id"])
                profile["fields"].append({"key": "hold_used_by_cabins", "label": "Hold used by cabins",
                    "number": initial * 5, "text": str(initial * 5) + " t", "unit": "t",
                    "status": "standard unladen refit", "basis": "Retained initial charter berths use 5t each; intrinsic operating quarters are outside cargo."})
            if "usable_cargo_after_fit" not in keys:
                profile["fields"].append({"key": "usable_cargo_after_fit", "label": "Usable cargo after fit",
                    "number": None, "text": "", "unit": "t", "status": "project gameplay balance", "basis": row["cargoBasis"]})
        cabin_hold = next((field["number"] for field in profile["fields"]
                           if field["key"] == "hold_used_by_cabins"), 0)
        if type(cabin_hold) is not int or not 0 <= cabin_hold <= selected["cargo"]:
            raise ValueError("Invalid retained cabin hold: " + result["id"])
        for field in profile["fields"]:
            key = CARGO_FIELDS.get(field["key"])
            if key is None:
                continue
            value = selected[key] - cabin_hold if field["key"] == "usable_cargo_after_fit" else selected[key]
            if field.get("number") != value:
                field.update(number=value, text=str(value) + " t", unit="t",
                             status="project gameplay balance", basis=row["cargoBasis"])
            elif row.get("refreshProjectCargoBasis", False):
                field["basis"] = row["cargoBasis"]


def require_consistent(ship, balances):
    """Prevent reference generation from advertising stale metadata or project cargo."""
    if ship != apply_balance(ship, balances):
        raise ValueError("Stale catalogue role/cargo definition: " + ship["id"])
