import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("definitions", Path(__file__).resolve().parents[1] / "generate-original-fleet-definitions.py")
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


class OriginalDefinitionTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.stage = self.root / "staging"
        (self.stage / "specs").mkdir(parents=True)
        self.raw = b'id="SH001"\nname="Original"\nfamily="family"\nrole="trader"\nplayerFlyable=true\npurchasePolicy="plughQuestFabrication"\nmetadata={flag=true, values=[1,2.5]}\ngame={cargo=63,speed=34.8,acceleration=9.6,energy=270,recharge=3.78,roll=0.88,pitch=0.77,yaw=0.72,shield=240,shieldRecharge=1.5,fuel=130,jump=9,spool=12,missiles=5,facings=15,cargoExpansion=25,price=0}\n'
        self.entry = {"id": "SH001", "spec": "specs/SH001.toml", "geometryAvailable": False, "sources": [{"path": "fleet-specs/SH001.toml", "sha256": ""}], "gameValidityIssues": ["price zero requires native policy change"], "dependencies": ["missing-mesh"]}
        self.write()

    def write(self):
        (self.stage / "specs/SH001.toml").write_bytes(self.raw)
        self.entry["sources"][0]["sha256"] = TOOL.hashlib.sha256(self.raw).hexdigest()
        (self.stage / "readiness.json").write_text(json.dumps({"ships": [self.entry]}))

    def test_determinism_all_metadata_and_invalid_native_value_retained(self):
        a = TOOL.generate(self.stage, self.root / "a", 1)
        b = TOOL.generate(self.stage, self.root / "b", 1)
        self.assertEqual(a, b)
        source = (self.root / "a/Sources/EliteCore/OriginalFleetDefinitions.generated.swift").read_text()
        self.assertEqual(source, (self.root / "b/Sources/EliteCore/OriginalFleetDefinitions.generated.swift").read_text())
        self.assertIn("price: 0,", source)
        self.assertIn('"price": .integer(0)', source)
        self.assertIn('"flag": .boolean(true)', source)
        self.assertIn('"values": .array([', source)
        self.assertIn('.number(2.5)', source)
        self.assertIn('purchasePolicy: "plughQuestFabrication"', source)
        self.assertIn('approvedMeshAvailable: false', source)
        self.assertIn('price zero requires native policy change', source)

    def test_swift_unicode_interpolation_and_integer_boundaries(self):
        self.assertEqual(TOOL.quote('"\\(bad)\n\x7f\U0001f680'), '"\\"\\\\(bad)\\u{a}\\u{7f}\\u{1f680}"')
        self.assertIn('Int64.min', TOOL.value_lines(TOOL.MIN_INT, '', 0)[0])
        self.assertIn('.largeInteger("9223372036854775808")', TOOL.value_lines(2**63, '', 0)[0])
        self.assertEqual(TOOL.value_lines(True, '', 0), ['.boolean(true)'])
        with self.assertRaises(ValueError):
            TOOL.value_lines(float('nan'), '', 0)
        with self.assertRaises(ValueError):
            TOOL.quote('\ud800')

    def test_unrepresentable_native_values_stay_in_typed_metadata(self):
        self.raw = self.raw.replace(b'cargo=63', b'cargo=9223372036854775808')
        self.write()
        result = TOOL.generate(self.stage, self.root / "out", 1)
        self.assertTrue(result['nativeRepresentationIssues'])
        data = (self.root / "out/Sources/EliteCore/OriginalFleetDefinitions.generated.swift").read_text()
        self.assertIn('.largeInteger("9223372036854775808")', data)
        self.assertIn('let performance: ShipPerformance? = nil', data)
        game = TOOL.tomllib.loads(self.raw.decode())["game"]
        for value in (2**53 + 1, 10**400):
            game["speed"] = value
            native, issues = TOOL.native_values(game)
            self.assertIsNone(native)
            self.assertTrue(any('game.speed' in issue for issue in issues))

    def test_missing_extra_duplicate_and_symlink_refusal(self):
        ready = self.stage / 'readiness.json'
        ready.write_text(json.dumps({'ships': [self.entry, self.entry]}))
        with self.assertRaises(ValueError):
            TOOL.generate(self.stage, self.root / 'duplicate', 1)
        ready.write_text(json.dumps({'ships': []}))
        with self.assertRaises(ValueError):
            TOOL.generate(self.stage, self.root / 'missing', 1)
        self.write()
        (self.stage / 'specs/SH002.toml').write_bytes(self.raw)
        with self.assertRaises(ValueError):
            TOOL.generate(self.stage, self.root / 'extra', 1)
        empty = self.root / 'empty'
        empty.mkdir()
        link = self.root / 'link'
        link.symlink_to(empty, target_is_directory=True)
        with self.assertRaises(ValueError):
            TOOL.generate(self.stage, link, 1)
        self.assertEqual(list(empty.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
