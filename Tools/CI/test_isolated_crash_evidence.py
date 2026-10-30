"""Synthetic processes/files only; no Swift child, native test, debugger or ps is executed."""
import io
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

import isolated_crash_evidence as evidence
import isolated_units as units


def row(parent, command='owned', start='Thu Oct 22 01:00:00 2026'):
    return {'parent': parent, 'command': command, 'start': start}


class IsolatedCrashEvidenceTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)

    def capture_snapshots(self, snapshots):
        process = SimpleNamespace(pid=10, exit_code=None)
        process.poll = lambda: process.exit_code
        samples = iter(snapshots)

        def read_snapshot():
            rows, process.exit_code = next(samples)
            return rows

        capture = evidence.IsolatedCrashEvidence(
            self.root, self.root / 'evidence', roots=[], read_snapshot=read_snapshot)
        # Run the observer synchronously against synthetic snapshots, without a thread or ps.
        with patch.object(evidence.threading, 'Thread') as thread, \
                patch.object(capture.stop, 'wait',
                             side_effect=[False] * (len(snapshots) - 1) + [True]):
            thread.return_value.start.side_effect = lambda: thread.call_args.kwargs['target']()
            capture.start(process)
        self.assertEqual(capture.errors, [])
        return capture

    def test_live_root_exec_keeps_both_commands_and_discovers_new_test_descendants(self):
        original = row(1, '/tool/swift test --filter selected')
        executed = row(1, '/tool/swift-test --filter selected')
        helper = row(10, '/tool/swiftpm-testing-helper --test-bundle-path native')
        native = row(11, '/build/L337PackageTests')
        capture = self.capture_snapshots([
            ({10: original}, None),
            ({10: executed, 11: helper}, None),
            ({10: executed, 11: helper, 12: native, 90: row(1, 'foreign')}, None),
        ])
        self.assertEqual(capture.history, {10: [original, executed], 11: [helper], 12: [native]})
        self.assertEqual(capture.known, {10: executed, 11: helper, 12: native})

    def test_exited_root_cannot_reenrol_even_with_the_same_start_and_command(self):
        original = row(1, '/tool/swift test --filter selected')
        capture = self.capture_snapshots([
            ({10: original}, None),
            ({}, 0),
            ({10: original, 11: row(10, '/tool/swiftpm-testing-helper')}, 0),
        ])
        self.assertEqual(capture.history, {10: [original]})

    def test_root_exit_during_first_snapshot_never_establishes_authority(self):
        capture = self.capture_snapshots([
            ({10: row(1, '/tool/swift test'),
              11: row(10, '/tool/swiftpm-testing-helper')}, 0),
        ])
        self.assertEqual(capture.history, {})
        self.assertEqual(capture.known, {})

    def test_live_poll_cannot_authorize_a_changed_start_root(self):
        original = row(1, '/tool/swift test --filter selected')
        replacement = row(1, '/tool/swift-test --filter selected', start='later')
        capture = self.capture_snapshots([
            ({10: original}, None),
            ({10: replacement, 11: row(10, '/tool/swiftpm-testing-helper')}, None),
        ])
        self.assertEqual(capture.history, {10: [original]})
        self.assertEqual(capture.known[10], original)

    def test_old_evidence_is_cleared_and_foreign_or_symbolic_roots_refused(self):
        directory = self.root / 'evidence'
        directory.mkdir()
        (directory / 'stale.ips').write_text('old run')
        evidence.IsolatedCrashEvidence(self.root, directory, roots=[])
        self.assertFalse(directory.exists())
        directory.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            evidence.IsolatedCrashEvidence(self.root, directory, roots=[])
        self.assertTrue(self.root.is_dir())
        with self.assertRaises(ValueError):
            evidence.IsolatedCrashEvidence(self.root, self.root.parent / 'outside', roots=[])

    def test_only_live_owned_ancestry_enters_history(self):
        rows = {10: row(1), 11: row(10, 'swift helper'), 12: row(11, 'native test'),
                90: row(1, 'unrelated'), 91: row(90, 'other test')}
        known, history = {}, {}
        evidence.observe_descendants(rows, 10, known, history, root_alive=True)
        self.assertEqual(set(history), {10, 11, 12})
        evidence.observe_descendants(rows, 10, known, history, root_alive=True)
        self.assertTrue(all(len(records) == 1 for records in history.values()))

    def test_reused_root_or_child_pid_cannot_confer_ownership(self):
        known, history = {}, {}
        evidence.observe_descendants({10: row(1), 11: row(10)}, 10, known, history,
                                     root_alive=True)
        reused = {10: row(1, start='later'), 11: row(1, start='later'), 12: row(11)}
        evidence.observe_descendants(reused, 10, known, history, root_alive=True)
        self.assertEqual(set(history), {10, 11})
        self.assertEqual(known[10]['start'], 'Thu Oct 22 01:00:00 2026')

    def test_changed_unowned_command_does_not_match_old_identity(self):
        known, history = {}, {}
        evidence.observe_descendants({10: row(1), 11: row(10)}, 10, known, history,
                                     root_alive=True)
        evidence.observe_descendants({11: row(1, command='unrelated exec'), 12: row(11)},
                                     10, known, history, root_alive=True)
        self.assertNotIn(12, history)
        self.assertEqual(history[11][0]['command'], 'owned')

    def test_completed_compiler_commands_are_not_retained_as_crash_history(self):
        capture = evidence.IsolatedCrashEvidence(self.root, self.root / 'evidence', roots=[])
        rows = {10: row(1, '/tool/swift test'),
                11: row(10, '/tool/swift-frontend ' + 'large-file.swift ' * 1000),
                12: row(10, '/tool/swiftpm-testing-helper --test-bundle-path native')}
        capture.observe(rows, 10, root_alive=True)
        self.assertEqual(set(capture.history), {10, 12})
        capture.observe({10: rows[10]}, 10, root_alive=True)
        self.assertEqual(set(capture.known), {10})
        self.assertEqual(set(capture.history), {10, 12})

    def test_snapshot_preserves_start_and_full_arguments_without_running_ps(self):
        text = ' 10 1 Thu Oct 22 01:00:00 2026 /tool/swift helper --filter selected name\n'
        with patch.object(evidence.subprocess, 'check_output', return_value=text) as read:
            rows = evidence.snapshot()
        self.assertEqual(rows[10]['start'], 'Thu Oct 22 01:00:00 2026')
        self.assertEqual(rows[10]['command'], '/tool/swift helper --filter selected name')
        self.assertEqual(read.call_args.kwargs['timeout'], 2)

    def test_failure_retains_only_exact_attributed_reports_and_existing_images(self):
        capture = evidence.IsolatedCrashEvidence(self.root, self.root / 'evidence', roots=[])
        capture.history = {10: [row(1)]}
        matched = {'matchedActualProcess': True, 'retained': 'matched-crashes/owned.ips'}
        other = {'matchedActualProcess': False, 'name': 'unrelated.ips'}
        with patch.object(evidence, 'retain_test_images', return_value=['existing image']) as images, \
                patch.object(evidence, 'collect_reports', return_value=([matched, other], {})) as reports:
            result = capture.finish('a' * 40, failed=True)
        self.assertEqual(result['reports'], 1)
        self.assertEqual(result['matchedReports'], 1)
        saved = json.loads((capture.evidence / 'crash-originals.json').read_text())
        self.assertEqual(saved, [matched])
        self.assertNotIn('observed_images', reports.call_args.kwargs)
        self.assertEqual(images.call_args.args[0], capture.history)

    def test_success_does_not_collect_reports_or_copy_images(self):
        capture = evidence.IsolatedCrashEvidence(self.root, self.root / 'evidence', roots=[])
        with patch.object(evidence, 'collect_reports') as reports, \
                patch.object(evidence, 'retain_test_images') as images:
            result = capture.finish('b' * 40, failed=False)
        reports.assert_not_called()
        images.assert_not_called()
        self.assertFalse(result['observerAlive'])
        self.assertFalse(capture.evidence.exists())

    def test_capture_error_is_reported_without_invented_crash_attribution(self):
        capture = evidence.IsolatedCrashEvidence(self.root, self.root / 'evidence', roots=[])
        with patch.object(evidence, 'retain_test_images', side_effect=OSError('fixture refusal')):
            result = capture.finish('c' * 40, failed=True)
        self.assertEqual(result['captureError']['type'], 'OSError')
        self.assertNotIn('matchedReports', result)

    def test_original_failed_unit_exit_and_child_environment_survive_capture_error(self):
        process = SimpleNamespace(stdout=iter(['fixture output\n']), wait=lambda: 10)
        class Child:
            def __enter__(self): return process
            def __exit__(self, *args): return False
        with patch.object(units, 'ROOT', self.root), \
                patch.object(units.subprocess, 'check_output', return_value='d' * 40), \
                patch.object(units.subprocess, 'Popen', return_value=Child()) as launch, \
                patch.object(units, 'IsolatedCrashEvidence') as hook, \
                patch.object(units, 'inspect_report') as inspect, \
                patch.dict(units.os.environ, {'FIXTURE_SECRET': 'never log this'}), \
                patch('sys.stdout', new=io.StringIO()):
            hook.return_value.finish.side_effect = OSError('fixture refusal')
            result = units.main()
        self.assertEqual(result, 10)
        inspect.assert_not_called()
        saved = json.loads((self.root / 'reports/isolated-units/result.json').read_text())
        self.assertEqual(saved['exit_code'], 10)
        self.assertEqual(saved['status'], 'failed')
        self.assertNotIn('never log this', json.dumps(saved))
        child_env = launch.call_args.kwargs['env']
        self.assertEqual(child_env['FIXTURE_SECRET'], 'never log this')
        self.assertIn('enable=no', child_env['SWIFT_BACKTRACE'])
        self.assertIn('interactive=no', child_env['SWIFT_BACKTRACE'])
        hook.return_value.start.assert_called_once_with(process)
        hook.return_value.finish.assert_called_once_with('d' * 40, failed=True)


if __name__ == '__main__':
    unittest.main()
