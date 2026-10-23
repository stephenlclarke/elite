"""Ensure the maintained equality inventory catches future omissions and ordering drift."""

import unittest

from script_instance_equality import COMMANDER_SOURCE, SOURCE, inspect_equality, inspect_instance_storage


class ScriptInstanceEqualityTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text()

    def test_all_actual_fields_are_compared(self):
        fields = inspect_equality(self.source)
        self.assertIn("savedNativeCrewLog", fields)
        self.assertIn("randomState", fields)

    def test_new_stored_field_cannot_be_silently_omitted(self):
        changed = self.source.replace(
            "    let id: UUID\n", "    let addedForFixture: String\n    let id: UUID\n", 1
        )
        with self.assertRaisesRegex(ValueError, "every stored field"):
            inspect_equality(changed)

    def test_missing_duplicate_or_reordered_comparisons_are_rejected(self):
        first = "    guard equalId(lhs.payload, rhs.payload) else { return false }\n"
        second = "    guard equalDefinition(lhs.payload, rhs.payload) else { return false }\n"
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
            "    let id: UUID\n",
            "    static let fixture: Int = 1\n    var computed: Int { 1 }\n    let id: UUID\n",
            1,
        )
        self.assertEqual(inspect_equality(changed), inspect_equality(self.source))

    def test_early_success_cannot_bypass_the_comparisons(self):
        changed = self.source.replace(
            "    guard equalId(lhs.payload, rhs.payload)", "    return true\n    guard equalId(lhs.payload, rhs.payload)", 1
        )
        with self.assertRaisesRegex(ValueError, "short circuit"):
            inspect_equality(changed)

    def test_observed_stored_properties_cannot_evade_the_inventory(self):
        for declaration in [
            "    var added: Int { didSet {} }\n",
            "    var added: Int {\n      willSet {}\n    }\n",
            "    var added: Int = 0 { didSet {} }\n",
        ]:
            with self.subTest(declaration=declaration):
                changed = self.source.replace("    let id: UUID\n", declaration + "    let id: UUID\n", 1)
                with self.assertRaisesRegex(ValueError, "Observed stored"):
                    inspect_equality(changed)

    def test_multiple_bindings_cannot_hide_the_second_stored_field(self):
        for declaration in [
            "    let added: Int, omitted: Int\n",
            "    var added: Int = 1, omitted: Int = 2\n",
        ]:
            with self.subTest(declaration=declaration):
                changed = self.source.replace("    let id: UUID\n", declaration + "    let id: UUID\n", 1)
                with self.assertRaisesRegex(ValueError, "Multiple bindings"):
                    inspect_equality(changed)

    def test_inferred_type_cannot_evade_the_inventory(self):
        changed = self.source.replace("    let id: UUID\n", "    let fixture = 1\n    let id: UUID\n", 1)
        with self.assertRaisesRegex(ValueError, "explicit type"):
            inspect_equality(changed)


class ScriptInstanceStorageInventoryTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text()
        self.fields = inspect_instance_storage(self.source)
        import re
        self.wrapped = set(re.findall(r"^    var (\w+): Field<[^\n]+>\?", self.source, re.M))
        self.assertEqual(len(self.fields), 51)

    def changed(self, before, after):
        self.assertIn(before, self.source)
        return self.source.replace(before, after, 1)

    def test_added_payload_or_facade_field_fails_closed(self):
        for before, after in [
            ("    let id: UUID", "    var omitted: Int = 0\n    let id: UUID"),
            ("  private var payload: Storage", "  var omitted: Int = 0\n  private var payload: Storage"),
        ]:
            with self.subTest(before=before), self.assertRaises(ValueError):
                inspect_instance_storage(self.changed(before, after))

    def test_every_mutable_projection_requires_both_detaches(self):
        for field in self.fields[4:]:
            field = field + ("!.value" if field in self.wrapped else "")
            for projection in [
                f"      ensureUniqueStorage()\n      payload.{field} = newValue",
                f"      ensureUniqueStorage()\n      yield &payload.{field}",
            ]:
                with self.subTest(field=field, projection=projection):
                    with self.assertRaisesRegex(ValueError, "detach before"):
                        inspect_instance_storage(self.changed(
                            projection, projection.replace("      ensureUniqueStorage()\n", "")))

    def test_shared_clone_and_each_field_copy_are_required(self):
        with self.assertRaisesRegex(ValueError, "clone shared"):
            inspect_instance_storage(self.changed(
                "payload = Storage(copying: payload)", "payload = payload"))
        for field in self.fields[4:]:
            helper = "copy" + field[0].upper() + field[1:]
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "allocate first"):
                inspect_instance_storage(self.changed(f"      {helper}(from: source)\n", ""))
        with self.assertRaisesRegex(ValueError, "same logical member"):
            inspect_instance_storage(self.changed("revision = source.revision", "revision = source.randomState"))

    def test_copy_helpers_cannot_be_inlined_into_an_aggregate_frame(self):
        with self.assertRaisesRegex(ValueError, "separate frames"):
            inspect_instance_storage(self.changed(
                "    @inline(never)\n    private func copyData", "    private func copyData"))

    def test_every_codec_key_and_encoder_call_is_required(self):
        for field in self.fields:
            helper = "encode" + field[0].upper() + field[1:]
            for before in [f"    case {field}\n", f"      try {helper}(to: &values)\n"]:
                with self.subTest(field=field, before=before), self.assertRaisesRegex(ValueError, "Codec"):
                    inspect_instance_storage(self.changed(before, ""))

    def test_required_decode_and_optional_omission_cannot_be_defaulted(self):
        for before, after in [
            ("values.decode(UInt64.self, forKey: .revision)", "values.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0"),
            ("values.decodeIfPresent(String.self, forKey: .suspension)", "values.decode(String.self, forKey: .suspension)"),
            ("values.encodeIfPresent(suspension, forKey: .suspension)", "values.encode(suspension, forKey: .suspension)"),
        ]:
            with self.subTest(before=before), self.assertRaisesRegex(ValueError, "Codec"):
                inspect_instance_storage(self.changed(before, after))


    def test_default_constructor_and_each_field_initializer_are_required(self):
        for name in self.wrapped:
            helper = "initialize" + name[0].upper() + name[1:]
            before = f"      {helper}()\n"
            with self.subTest(field=name), self.assertRaisesRegex(ValueError, "Default construction"):
                inspect_instance_storage(self.changed(before, ""))
        with self.assertRaisesRegex(ValueError, "Clone allocation"):
            inspect_instance_storage(self.changed(
                "      self.digest = digest", "      self.digest = digest\n      initializeSavedGlassMeridian()"))

    def test_child_handle_cannot_replace_the_original_logical_equality(self):
        with self.assertRaisesRegex(ValueError, "logical field values"):
            inspect_instance_storage(self.changed(
                "lhs.savedGlassMeridian!.value == rhs.savedGlassMeridian!.value",
                "lhs.savedGlassMeridian == rhs.savedGlassMeridian"))

    def test_typed_field_cow_and_initialized_count_cannot_be_removed(self):
        for before, after in [
            ("_modify { yield &values[0] }", "_modify { fatalError() }"),
            ("initializedCount = 1", "initializedCount = 0"),
            ("initialize(from: source, count: 1)", "initialize(to: source.pointee)"),
        ]:
            with self.subTest(before=before), self.assertRaisesRegex(ValueError, "typed Array COW"):
                inspect_instance_storage(self.changed(before, after))


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
