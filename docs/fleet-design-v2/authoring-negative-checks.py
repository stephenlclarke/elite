"""Exercise review guards on isolated design copies. No game or native tests."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile
import tomllib

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("fleet_authoring_review", ROOT / "authoring.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def change_scalar(text, key, value):
    """Change one exact top-level or section scalar without mutating other data."""
    result, count = re.subn(r"(?m)^" + re.escape(key) + r" = .*$", key + " = " + value, text)
    assert count == 1, key
    return result


def change_performance(text, key, value):
    """Mutate stock only; candidate upgraded fields deliberately stay untouched."""
    before, remainder = text.split("\n[performance]\n", 1)
    section, after = remainder.split("\n[", 1)
    return before + "\n[performance]\n" + change_scalar(section, key, value) + "\n[" + after


with tempfile.TemporaryDirectory(prefix="l337-fleet-authoring-negative-") as temporary:
    isolated = Path(temporary) / "fleet"
    shutil.copytree(ROOT, isolated, ignore=shutil.ignore_patterns("__pycache__"))
    with contextlib.redirect_stdout(io.StringIO()):
        module.validate(isolated)
    passed = []

    def refuses(name, path, mutation, expected_reason=None):
        """Run the real validator and require the intended guard to reject a copy."""
        original = path.read_text()
        path.write_text(mutation(original))
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                module.validate(isolated)
        except AssertionError as error:
            if expected_reason is not None:
                assert expected_reason in str(error), (name, str(error))
            passed.append(name)
        else:
            raise AssertionError("Validator accepted " + name)
        finally:
            path.write_text(original)

    ordinary = isolated / "ships/SH046.toml"
    refuses("free initial cabin", ordinary,
            lambda text: change_scalar(text, "initialPurchasedCabins", "1"), "no-free-cabins")
    refuses("free included role kit", ordinary,
            lambda text: change_scalar(text, "roleKitIncludedInBareHull", "true"), "no-free-role-kit")

    medusa = isolated / "ships/SH171.toml"
    current = tomllib.loads(medusa.read_text())
    for source_key, field in module.MEDUSA_STOCK_FIELDS.items():
        value = current["performance"][field]
        changed = 7 if field == "laserFacingMask" else value + 1
        refuses("Medusa stock " + source_key, medusa,
                lambda text, key=field, replacement=changed: change_performance(text, key, repr(replacement)),
                "Medusa all17 stock fields")
    keys = current["medusaConfigurations"]["configurationKeys"]
    refuses("missing Medusa configuration", medusa,
            lambda text: change_scalar(text, "configurationKeys", json.dumps(keys[1:])),
            "Medusa configuration keys")
    copied_source = isolated / "references/salvage/MEDUSA-FLAGSHIP.json"
    refuses("changed source fingerprint", copied_source, lambda text: text + "\n")
    with contextlib.redirect_stdout(io.StringIO()):
        module.validate(isolated)

report = {
    "scope": "Authoring-only isolated data mutations; no runtime/native/game/compiler execution",
    "baselineAndRestoredCopies": "PASS",
    "rejectedMutations": passed,
    "negativeCases": len(passed),
    "stockFieldsIndividuallyChecked": len(module.MEDUSA_STOCK_FIELDS),
    "liveShipContractsMutated": False,
    "result": "PASS",
}
(ROOT / "AUTHORING-NEGATIVE-CHECKS.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"negativeCases": len(passed), "stockFields": len(module.MEDUSA_STOCK_FIELDS), "result": "PASS"}))
