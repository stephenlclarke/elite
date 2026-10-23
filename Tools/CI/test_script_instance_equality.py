"""Ensure the maintained equality inventory catches future omissions and ordering drift."""

import unittest

from script_instance_equality import COMMANDER_SOURCE, SOURCE, inspect_equality


class ScriptInstanceEqualityTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text()

    def test_all_actual_fields_are_compared(self):
        fields = inspect_equality(self.source)
        self.assertIn("savedNativeCrewLog", fields)
        self.assertIn("randomState", fields)

    def test_new_stored_field_cannot_be_silently_omitted(self):
        changed = self.source.replace(
            "  let id: UUID\n", "  let addedForFixture: String\n  let id: UUID\n", 1
        )
        with self.assertRaisesRegex(ValueError, "every stored field"):
            inspect_equality(changed)

    def test_missing_duplicate_or_reordered_comparisons_are_rejected(self):
        first = "    guard equalId(lhs, rhs) else { return false }\n"
        second = "    guard equalDefinition(lhs, rhs) else { return false }\n"
        for changed in [
            self.source.replace(first, "", 1),
            self.source.replace(first, first + first, 1),
            self.source.replace(first + second, second + first, 1),
        ]:
            with self.subTest(changed=changed[:40]):
                with self.assertRaisesRegex(ValueError, "every stored field"):
                    inspect_equality(changed)

    def test_different_member_on_right_is_rejected(self):
        changed = self.source.replace("lhs.id == rhs.id", "lhs.id == rhs.definition", 1)
        with self.assertRaisesRegex(ValueError, "same member"):
            inspect_equality(changed)

    def test_computed_and_static_properties_are_not_stored_equality_fields(self):
        changed = self.source.replace(
            "  let id: UUID\n",
            "  static let fixture: Int = 1\n  var computed: Int { 1 }\n  let id: UUID\n",
            1,
        )
        self.assertEqual(inspect_equality(changed), inspect_equality(self.source))

    def test_early_success_cannot_bypass_the_comparisons(self):
        changed = self.source.replace(
            "    guard equalId(lhs, rhs)", "    return true\n    guard equalId(lhs, rhs)", 1
        )
        with self.assertRaisesRegex(ValueError, "short circuit"):
            inspect_equality(changed)

    def test_observed_stored_properties_cannot_evade_the_inventory(self):
        for declaration in [
            "  var added: Int { didSet {} }\n",
            "  var added: Int {\n    willSet {}\n  }\n",
            "  var added: Int = 0 { didSet {} }\n",
        ]:
            with self.subTest(declaration=declaration):
                changed = self.source.replace("  let id: UUID\n", declaration + "  let id: UUID\n", 1)
                with self.assertRaisesRegex(ValueError, "Observed stored"):
                    inspect_equality(changed)

    def test_multiple_bindings_cannot_hide_the_second_stored_field(self):
        for declaration in [
            "  let added: Int, omitted: Int\n",
            "  var added: Int = 1, omitted: Int = 2\n",
        ]:
            with self.subTest(declaration=declaration):
                changed = self.source.replace("  let id: UUID\n", declaration + "  let id: UUID\n", 1)
                with self.assertRaisesRegex(ValueError, "Multiple bindings"):
                    inspect_equality(changed)

    def test_inferred_type_cannot_evade_the_inventory(self):
        changed = self.source.replace("  let id: UUID\n", "  let fixture = 1\n  let id: UUID\n", 1)
        with self.assertRaisesRegex(ValueError, "explicit type"):
            inspect_equality(changed)


class ScriptEngineEqualityInventoryTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text()

    def test_actual_fields_include_inferred_clocks_and_exclude_computed_aliases(self):
        fields = inspect_equality(self.source, "ScriptEngineState")
        self.assertEqual(fields[-4:], [
            "flightSeconds", "localSeconds", "calendarSeconds", "transitSeconds"
        ])
        self.assertIn("savedWorldJobs", fields)
        self.assertNotIn("worldJobs", fields)

    def test_added_engine_stored_field_cannot_be_omitted(self):
        changed = self.source.replace(
            "  var savedMeasuredExtractionSource:",
            "  var omittedByFixture: Int\n  var savedMeasuredExtractionSource:",
            1,
        )
        with self.assertRaisesRegex(ValueError, "every stored field"):
            inspect_equality(changed, "ScriptEngineState")

    def test_engine_stored_field_after_initializer_cannot_evade_inventory(self):
        changed = self.source.replace(
            "  public init() {}",
            "  public init() {}\n  public var omittedAfterInitializer: Int = 0",
            1,
        )
        with self.assertRaisesRegex(ValueError, "every stored field"):
            inspect_equality(changed, "ScriptEngineState")

    def test_only_original_inferred_clock_declarations_are_supported(self):
        changed = self.source.replace(
            "  public var flightSeconds = 0.0", "  public var addedByFixture = 0.0\n  public var flightSeconds = 0.0", 1
        )
        with self.assertRaisesRegex(ValueError, "explicit type"):
            inspect_equality(changed, "ScriptEngineState")


class CommanderEqualityInventoryTests(unittest.TestCase):
    def setUp(self):
        self.source = COMMANDER_SOURCE.read_text()

    def test_private_saved_fields_are_compared_instead_of_defaulting_projections(self):
        fields = inspect_equality(self.source, "Commander")
        self.assertIn("savedScriptState", fields)
        self.assertIn("savedNativePeopleCustodyStorage", fields)
        self.assertNotIn("scriptState", fields)
        self.assertNotIn("savedNativePeopleCustody", fields)

    def test_added_commander_stored_field_after_initializer_is_rejected(self):
        changed = self.source.replace(
            "  public var availableCredits: Int {",
            "  var omittedByFixture: Int\n  public var availableCredits: Int {",
            1,
        )
        with self.assertRaisesRegex(ValueError, "every stored field"):
            inspect_equality(changed, "Commander")

    def test_unknown_commander_inferred_declaration_is_rejected(self):
        changed = self.source.replace(
            "  public var name = NewCommanderDefaults.name",
            "  var addedByFixture = false\n  public var name = NewCommanderDefaults.name",
            1,
        )
        with self.assertRaisesRegex(ValueError, "explicit type"):
            inspect_equality(changed, "Commander")


if __name__ == "__main__":
    unittest.main()
