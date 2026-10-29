"""Small offline regression checks for the shared-controls generation boundary."""

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("flight_controls", REPO / "Tools/generate-flight-controls.py")
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)
AUTHORITY = json.loads((REPO / "config/flight-controls.json").read_text())


class FlightControlsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.input = self.root / "authority.json"
        self.write(AUTHORITY)

    def write(self, data):
        self.input.write_text(json.dumps(data, ensure_ascii=True) + "\n")

    def run_cli(self, *arguments):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            status = GENERATOR.main(["--repo-root", str(self.root), "--input", str(self.input), *arguments])
        return status, output.getvalue()

    def test_deterministic_generation_and_read_only_check(self):
        self.assertEqual(self.run_cli("--check")[0], 1)
        self.assertFalse((self.root / "Sources").exists())
        self.assertEqual(self.run_cli()[0], 0)
        paths = [self.root / GENERATOR.SWIFT_PATH, self.root / GENERATOR.MARKDOWN_PATH]
        original = [path.read_bytes() for path in paths]
        timestamps = [path.stat().st_mtime_ns for path in paths]
        self.assertEqual(self.run_cli("--check")[0], 0)
        self.assertEqual([path.stat().st_mtime_ns for path in paths], timestamps)
        self.assertEqual(self.run_cli()[0], 0)
        self.assertEqual([path.read_bytes() for path in paths], original)
        paths[0].write_text("stale\n")
        self.assertEqual(self.run_cli("--check")[0], 1)
        self.assertEqual(paths[0].read_text(), "stale\n")

    def test_duplicate_conflicting_missing_and_extra_bindings_rejected(self):
        for mutation in ("duplicate", "key", "label", "missing", "extra"):
            with self.subTest(mutation=mutation):
                data = copy.deepcopy(AUTHORITY)
                if mutation == "duplicate":
                    data["bindings"].append(copy.deepcopy(data["bindings"][0]))
                elif mutation == "key":
                    data["bindings"][1]["key"] = "W"
                elif mutation == "label":
                    data["bindings"][1]["action"] = "Mine"
                elif mutation == "missing":
                    data["bindings"].pop()
                else:
                    data["bindings"].append({"id": "unexpected", "key": "A", "action": "Other", "detail": "Other"})
                self.write(data)
                self.assertEqual(self.run_cli()[0], 2)
                self.assertFalse((self.root / "Sources").exists())

    def test_missing_extra_duplicate_topics_and_stale_labels_rejected(self):
        for mutation in ("missing", "extra", "duplicate", "stale", "footer", "weapon", "indicator"):
            with self.subTest(mutation=mutation):
                data = copy.deepcopy(AUTHORITY)
                if mutation == "missing":
                    data["helpTopics"].pop()
                elif mutation in ("extra", "duplicate"):
                    topic = copy.deepcopy(data["helpTopics"][0])
                    if mutation == "extra":
                        topic["id"] = "extra"
                    data["helpTopics"].append(topic)
                elif mutation == "stale":
                    data["helpTopics"][0]["detail"] = "W: Change tool"
                elif mutation == "footer":
                    data["footer"] = "RETURN: MINE"
                elif mutation == "weapon":
                    data["weaponNames"][0] = "Combat tool"
                else:
                    data["weaponIndicator"]["help"] = "Q: OFF"
                self.write(data)
                self.assertEqual(self.run_cli()[0], 2)

    def test_duplicate_json_members_and_executable_input_rejected(self):
        for raw in ('{"schema": "a", "schema": "b"}', "__import__('os').system('false')", '{"invalid": NaN}'):
            with self.subTest(raw=raw):
                self.input.write_text(raw)
                self.assertEqual(self.run_cli()[0], 2)
        data = copy.deepcopy(AUTHORITY)
        data["provenance"]["sources"][0]["path"] = "../../escape"
        self.write(data)
        self.assertEqual(self.run_cli()[0], 2)

    def test_real_oversized_authority_refused_before_any_output_write(self):
        self.input.write_bytes(self.input.read_bytes() + b" " * GENERATOR.MAX_AUTHORITY_BYTES)
        self.assertGreater(self.input.stat().st_size, GENERATOR.MAX_AUTHORITY_BYTES)
        status, output = self.run_cli()
        self.assertEqual(status, 2)
        self.assertIn("Authority exceeds 1 MiB", output)
        self.assertEqual({path.name for path in self.root.iterdir()}, {"authority.json"})

    def test_swift_escaping_blocks_interpolation_and_preserves_unicode(self):
        value = '"\\(danger)\n\t\r\0' + "\u00e9\U0001f680\u2028"
        expected = '"\\"\\\\(danger)\\u{a}\\u{9}\\u{d}\\u{0}\\u{e9}\\u{1f680}\\u{2028}"'
        self.assertEqual(GENERATOR.swift_string(value), expected)
        data = copy.deepcopy(AUTHORITY)
        data["helpTopics"][0]["detail"] = value
        self.write(data)
        self.assertEqual(self.run_cli()[0], 0)
        swift = (self.root / GENERATOR.SWIFT_PATH).read_text()
        self.assertIn(expected, swift)
        self.assertNotIn(value, swift)
        self.assertNotIn("\\u00e9", swift)

    def test_all_topics_share_bindings_and_separate_menu_context(self):
        self.assertEqual(self.run_cli()[0], 0)
        markdown = (self.root / GENERATOR.MARKDOWN_PATH).read_text()
        self.assertEqual(markdown.count("### Flight controls:"), 15)
        self.assertEqual(markdown.count("### Separate menu context:"), 15)
        headings = [line for line in markdown.splitlines() if line.startswith("#")]
        self.assertEqual(len(headings), len(set(headings)))
        for identifier in GENERATOR.TOPICS:
            self.assertIn(f"Topic ID: `{identifier}`.", markdown)
        self.assertEqual(markdown.count("| Return | Fire |"), 15)
        self.assertIn("readiness transition", markdown)
        self.assertIn("strictly less than 5%", markdown)
        self.assertIn("without releasing hold", markdown)

    def test_target_bindings_are_pinned_and_generated_for_every_topic(self):
        self.assertEqual(self.run_cli()[0], 0)
        markdown = (self.root / GENERATOR.MARKDOWN_PATH).read_text()
        self.assertEqual(markdown.count("| Tab | Next target |"), 15)
        self.assertEqual(markdown.count("| F | Target filter |"), 15)
        swift = (self.root / GENERATOR.SWIFT_PATH).read_text()
        self.assertIn('case nextTarget = "next_target"', swift)
        self.assertIn('case targetFilter = "target_filter"', swift)

    def test_target_key_conflicts_refuse_before_output(self):
        for identifier in ("next_target", "target_filter"):
            with self.subTest(identifier=identifier):
                data = copy.deepcopy(AUTHORITY)
                binding = next(item for item in data["bindings"] if item["id"] == identifier)
                binding["key"] = "Return"
                self.write(data)
                self.assertEqual(self.run_cli()[0], 2)
                self.assertFalse((self.root / "Sources").exists())

    def test_swift_repo_style_and_long_declarations(self):
        self.assertEqual(self.run_cli()[0], 0)
        swift = (self.root / GENERATOR.SWIFT_PATH).read_text()
        self.assertIn("\n  public enum ActionID:", swift)
        self.assertIn("return Binding(\n          id: self", swift)
        self.assertIn("public static let authoritySHA256 =\n    \"", swift)
        self.assertEqual(GENERATOR.swift_constant("short", "value"), ['  public static let short = "value"'])
        self.assertEqual(GENERATOR.swift_detail("short"), ['          detail: "short"'])

    def test_output_symlink_cannot_escape_or_modify_other_files(self):
        outside = self.root / "outside"
        outside.mkdir()
        sentinel = outside / "FlightControlAuthority.swift"
        sentinel.write_text("preserve")
        (self.root / "Sources").symlink_to(outside, target_is_directory=True)
        self.assertEqual(self.run_cli()[0], 2)
        self.assertEqual(sentinel.read_text(), "preserve")
        self.assertFalse((self.root / "docs").exists())


if __name__ == "__main__":
    unittest.main()
