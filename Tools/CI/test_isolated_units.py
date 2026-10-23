"""Unit fixtures for CI selection and report completeness; never launch Swift."""

from pathlib import Path
import re
import tempfile
import unittest
import xml.etree.ElementTree as ET

import isolated_units as units


class IsolatedReportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "tests.xml"

    def report(self):
        root = ET.Element("testsuites")
        suite = ET.SubElement(root, "testsuite")
        for name, methods in units.METHODS.items():
            for method in methods:
                ET.SubElement(suite, "testcase", classname=name, name=method + "()")
        return root, suite

    def write(self, root):
        ET.ElementTree(root).write(self.path)

    def test_complete_report_records_actual_cases(self):
        root, suite = self.report()
        self.write(root)
        result = units.inspect_report(self.path)
        self.assertEqual(result["methods"], 410)
        self.assertEqual(result["reported_testcases"], len(suite))

    def test_empty_report_does_not_pass_on_zero_process_exit(self):
        self.write(ET.Element("testsuites"))
        with self.assertRaisesRegex(ValueError, "no test cases"):
            units.inspect_report(self.path)

    def test_missing_selected_method_cannot_be_hidden_by_duplicate_other_cases(self):
        root, suite = self.report()
        suite.remove(suite[0])
        ET.SubElement(suite, "testcase", **suite[-1].attrib)
        self.write(root)
        with self.assertRaisesRegex(ValueError, "Missing selected"):
            units.inspect_report(self.path)

    def test_failure_error_and_skip_are_not_success(self):
        for issue in ("failure", "error", "skipped"):
            with self.subTest(issue=issue):
                root, suite = self.report()
                ET.SubElement(suite[0], issue)
                self.write(root)
                with self.assertRaises(ValueError):
                    units.inspect_report(self.path)

    def test_unselected_method_and_suite_error_totals_are_rejected(self):
        root, suite = self.report()
        ET.SubElement(suite, "testcase", classname="GameRuntimeTests", name="journey()")
        self.write(root)
        with self.assertRaisesRegex(ValueError, "outside"):
            units.inspect_report(self.path)
        root, suite = self.report()
        suite.set("errors", "1")
        self.write(root)
        with self.assertRaisesRegex(ValueError, "suite reports"):
            units.inspect_report(self.path)

    def test_filter_selects_only_named_methods_in_the_named_suites(self):
        pattern = re.compile(units.selection())
        for suite, methods in units.METHODS.items():
            for method in methods:
                self.assertIsNotNone(pattern.search(f"EliteCoreTests.{suite}/{method}()"))
                self.assertIsNone(pattern.search(f"EliteCoreTests.OtherSuite/{method}()"))
                self.assertIsNone(pattern.search(f"EliteCoreTests.{suite}/{method}Journey()"))
        self.assertIsNone(pattern.search("EliteCoreTests.NativeMeasuredExtractionJourneyTests/fullJourney()"))


if __name__ == "__main__":
    unittest.main()
