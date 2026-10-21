"""Filesystem/report fixtures only: never launch make, the app or a native test image."""
from datetime import datetime, timedelta
import hashlib
import io
import json
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import crash_artifacts as artifacts


class RuntimeChildEnvironmentTests(unittest.TestCase):
    def test_child_keeps_unrelated_values_without_mutating_parent(self):
        parent = {'PATH': '/toolchain/bin', 'LLVM_PROFILE_FILE': '/profiles/%m.profraw',
                  'DYLD_INSERT_LIBRARIES': '/runtime/libclang_rt.asan.dylib',
                  'SECRET_FIXTURE_ONLY': 'must-never-be-logged'}
        before = dict(parent)
        child = artifacts.runtime_child_environment(parent)
        self.assertEqual(parent, before)
        self.assertIsNot(child, parent)
        self.assertEqual({key: child[key] for key in parent}, before)
        self.assertEqual(set(child) - set(parent), {'SWIFT_BACKTRACE'})
        child['PATH'] = '/changed-child'
        self.assertEqual(parent, before)

    def test_conflicting_inherited_options_cannot_enable_interaction_or_file_output(self):
        parent = {'SWIFT_BACKTRACE': 'enable=no,interactive=yes,output-to=/tmp/report',
                  'UNRELATED': 'preserved'}
        child = artifacts.runtime_child_environment(parent)
        self.assertEqual(parent['SWIFT_BACKTRACE'],
                         'enable=no,interactive=yes,output-to=/tmp/report')
        self.assertEqual(child['UNRELATED'], 'preserved')
        self.assertEqual(child['SWIFT_BACKTRACE'],
                         artifacts.runtime_child_environment({})['SWIFT_BACKTRACE'])

    def test_effective_options_are_noninteractive_crashed_thread_stderr_only(self):
        setting = artifacts.runtime_child_environment({})['SWIFT_BACKTRACE']
        options = dict(item.split('=', 1) for item in setting.split(','))
        self.assertEqual(options, {'enable': 'yes', 'interactive': 'no', 'color': 'no',
                                   'output-to': 'stderr', 'threads': 'crashed',
                                   'registers': 'crashed', 'images': 'mentioned'})
        self.assertEqual(len(setting.split(',')), len(options))



class OwnedFaultStackTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.workspace = Path(temporary.name).resolve()
        self.evidence = self.workspace / 'evidence'
        self.evidence.mkdir()
        self.image = self.workspace / '.build/arm64-apple-macosx/debug/ElitePackageTests.xctest/Contents/MacOS/ElitePackageTests'
        self.image.parent.mkdir(parents=True)
        self.image.write_bytes(b'fake-image-never-executed')
        self.argv = ['/toolchain/swiftpm-testing-helper', '--test-bundle-path', str(self.image),
                     '--enable-code-coverage', str(self.image), '--testing-library', 'swift-testing']
        self.row = {'start': 'Wed Oct 21 01:31:44 2026', 'command': shlex.join(self.argv), 'parent': 10}
        self.rows = {21: dict(self.row)}
        self.cleaned = []
        self.calls = []
        self.session = {'pid': 21, 'status': 'target-exited', 'handedBack': True}
        self.payload = b'bounded debugger fixture output'
        self.timeout = False
        self.observer_code = 0
        self.budget = artifacts.ArtifactBudget()
        self.hook = artifacts.OwnedFaultStack(
            self.workspace, self.evidence, self.budget, self.snapshot, self.cleanup, self.popen)

    def snapshot(self):
        return {pid: dict(row) for pid, row in self.rows.items()}

    def cleanup(self, identity):
        if artifacts.same_process(identity, self.rows.get(identity['pid'])):
            self.cleaned.append(identity['pid'])
            self.rows.pop(identity['pid'])

    def popen(self, command, **kwargs):
        self.calls.append((command, kwargs))
        self.rows[55] = {'start': 'observer-start', 'command': 'fixture-lldb', 'parent': 10}
        self.rows[56] = {'start': 'server-start', 'command': 'fixture-debugserver', 'parent': 55}
        if self.session is not None:
            self.hook.session.write_text(json.dumps(self.session))
        owner = self

        class Observer:
            pid = 55
            stdout = io.BytesIO(owner.payload)

            def poll(self):
                return owner.observer_code

            def wait(self, timeout):
                if owner.timeout:
                    raise subprocess.TimeoutExpired(command, timeout)
                if owner.observer_code is None:
                    owner.observer_code = 0
                return owner.observer_code

        return Observer()

    def start(self):
        self.hook.consider({21: self.row})

    def test_only_exact_unfiltered_normal_owned_coverage_is_eligible(self):
        self.assertIsNotNone(artifacts.coverage_helper(21, self.row, self.workspace))
        for change in [self.argv + ['--filter', 'aTest'],
                       [item.replace('/arm64-apple-macosx/debug/', '/tsan/debug/') for item in self.argv],
                       [item.replace('/arm64-apple-macosx/debug/', '/asan/debug/') for item in self.argv],
                       [item.replace('--enable-code-coverage', '--other') for item in self.argv]]:
            self.assertIsNone(artifacts.coverage_helper(
                21, dict(self.row, command=shlex.join(change)), self.workspace))
        self.hook.consider({})
        self.assertFalse(self.hook.attempted)
        self.assertEqual(self.calls, [])

    def test_reused_pid_is_rejected_before_attach_and_consumes_one_attempt(self):
        self.rows[21]['start'] = 'foreign-reused-pid'
        self.start()
        self.rows[21] = dict(self.row)
        self.start()
        self.assertTrue(self.hook.attempted)
        self.assertEqual(self.calls, [])
        self.assertEqual(self.cleaned, [])

    def test_early_exit_is_not_attached_or_cleaned_up(self):
        self.rows.clear()
        self.start()
        self.assertEqual(self.hook.finish()['status'], 'identity-changed-or-exited')
        self.assertEqual(self.calls, [])
        self.assertEqual(self.cleaned, [])

    def test_one_attempt_and_explicit_no_init_pid_session_command(self):
        self.start()
        self.start()
        result = self.hook.finish()
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.calls[0][0][:5],
                         ['xcrun', 'lldb', '--no-lldbinit', '--batch', '-o'])
        self.assertEqual(result['status'], 'target-exited')
        self.assertFalse(result['diagnosticallyInterrupted'])
        self.assertEqual(self.cleaned, [])

    def test_attach_denial_is_logged_once_without_cleanup_or_retry(self):
        self.session.update(status='attach-denied', error='fixture permission denial')
        self.start()
        result = self.hook.finish()
        self.start()
        self.assertEqual(result['status'], 'attach-denied')
        self.assertFalse(result['diagnosticallyInterrupted'])
        self.assertEqual(self.cleaned, [])
        self.assertEqual(len(self.calls), 1)

    def test_unresolved_detach_requires_guarded_owned_cleanup_before_teardown(self):
        self.session.update(status='fault-captured', handedBack=False)
        self.observer_code = None
        self.start()
        self.rows[77] = {'start': 'foreign', 'command': 'unrelated', 'parent': 1}
        self.hook.poll()
        result = self.hook.finish()
        self.assertEqual(result['status'], 'DIAGNOSTICALLY_INTERRUPTED')
        self.assertEqual(set(self.cleaned), {21, 55, 56})
        self.assertIn(77, self.rows)
        self.assertEqual(result['remainingMatchedOwned'], [])

    def test_timeout_cleans_only_still_matching_owned_identities(self):
        self.timeout, self.observer_code = True, None
        self.start()
        self.rows[21]['start'] = 'reused-target'
        result = self.hook.finish()
        self.assertTrue(result['diagnosticallyInterrupted'])
        self.assertNotIn(21, self.cleaned)
        self.assertEqual(set(self.cleaned), {55, 56})
        self.assertIn(21, self.rows)

    def test_missing_session_observer_failure_is_inconclusive(self):
        self.session = None
        self.start()
        result = self.hook.finish()
        self.assertTrue(result['diagnosticallyInterrupted'])
        self.assertEqual(set(self.cleaned), {21, 55, 56})

    def test_observer_exception_cleanup_retains_unclosed_target_as_inconclusive(self):
        self.start()
        def refused_cleanup(identity):
            raise PermissionError('fixture cleanup denied')
        self.hook.cleanup = refused_cleanup
        self.hook._interrupt('fixture observer failure')
        result = self.hook.finish()
        self.assertTrue(result['diagnosticallyInterrupted'])
        self.assertIn(21, result['remainingMatchedOwned'])
        self.assertIn('cleanup denied', result['cleanupError'])

    def test_log_cap_is_reserved_then_charged_once_in_shared_budget(self):
        self.payload = b'x' * (artifacts.FAULT_LOG_LIMIT + 4096)
        self.start()
        self.assertEqual(self.budget.used, artifacts.FAULT_LOG_LIMIT)
        result = self.hook.finish()
        self.assertTrue(result['logTruncated'])
        self.assertEqual(self.hook.log.stat().st_size, artifacts.FAULT_LOG_LIMIT)
        self.assertEqual(self.budget.used, artifacts.FAULT_LOG_LIMIT)
        self.hook.finish()
        self.assertEqual(self.budget.used, artifacts.FAULT_LOG_LIMIT)

    def test_budget_refusal_never_starts_debugger(self):
        self.budget.limit = artifacts.FAULT_LOG_LIMIT - 1
        self.start()
        self.assertEqual(self.hook.finish()['status'], 'diagnostic-budget-refused')
        self.assertEqual(self.calls, [])
        self.assertEqual(self.budget.used, 0)

    def test_actual_cleanup_rechecks_reused_pid_between_term_and_kill(self):
        identity = dict(self.row, pid=21)
        sent = []
        def send(pid, signum):
            sent.append((pid, signum))
            self.rows[21]['start'] = 'foreign-after-term'
        artifacts.cleanup_owned_identity(identity, self.snapshot, send_signal=send)
        self.assertEqual(sent, [(21, artifacts.signal.SIGTERM)])
        self.assertEqual(self.rows[21]['start'], 'foreign-after-term')

    def test_actual_cleanup_escalates_only_same_owned_identity_under_existing_budget(self):
        identity = dict(self.row, pid=21)
        sent = []
        ticks = iter(range(30))
        def send(pid, signum):
            sent.append((pid, signum))
            if signum == artifacts.signal.SIGKILL:
                self.rows.pop(pid)
        artifacts.cleanup_owned_identity(
            identity, self.snapshot, send_signal=send, clock=lambda: next(ticks), sleep=lambda _: None)
        self.assertEqual(sent, [(21, artifacts.signal.SIGTERM), (21, artifacts.signal.SIGKILL)])
        self.assertNotIn(21, self.rows)

    def test_actual_result_is_preserved_and_inconclusive_never_becomes_pass(self):
        for original in (2, -4, 130):
            result = {'status': 'DIAGNOSTICALLY_INTERRUPTED', 'diagnosticallyInterrupted': True}
            self.assertEqual(artifacts.fault_capture_exit_code(original, result), original)
        result = {'status': 'DIAGNOSTICALLY_INTERRUPTED', 'diagnosticallyInterrupted': True}
        self.assertEqual(artifacts.fault_capture_exit_code(0, result), 125)
        result = {'status': 'fault-captured', 'diagnosticallyInterrupted': False}
        self.assertEqual(artifacts.fault_capture_exit_code(0, result), 125)
        self.assertTrue(result['diagnosticallyInterrupted'])
        result = {'status': 'attach-denied', 'diagnosticallyInterrupted': False}
        self.assertEqual(artifacts.fault_capture_exit_code(0, result), 0)

    def run_session(self, mode):
        identity = artifacts.coverage_helper(21, self.row, self.workspace)
        identity_path = self.evidence / 'identity.json'
        identity_path.write_text(json.dumps(identity))
        calls = []
        class Error:
            failed = False
            def Fail(self): return self.failed
            def Success(self): return not self.failed
        class Process:
            state = 1
            stop_id = 1
            def GetStopID(self): return self.stop_id
            def IsValid(self): return mode != 'denied'
            def GetState(self): return self.state
            def GetUnixSignals(self):
                return SimpleNamespace(SetShouldStop=lambda *a: True,
                                       SetShouldNotify=lambda *a: True,
                                       SetShouldSuppress=lambda *a: calls.append(('pass', a)) or True)
            def Continue(self):
                calls.append('continue')
                if mode == 'exception': raise RuntimeError('fixture observer exception')
                self.state = 3 if mode == 'exit' else 1
                if mode != 'stale-attach-stop': self.stop_id += 1
                return Error()
            def __iter__(self):
                return iter([SimpleNamespace(GetStopReason=lambda: 9)])
            def Detach(self, keep_stopped):
                calls.append(('detach', keep_stopped))
                error = Error()
                if mode == 'detach-failure':
                    error.failed = True
                    self.state = 3
                else:
                    self.state = 4
                return error
        process = Process()
        def attach(listener, pid, error):
            calls.append(('attach', pid))
            error.failed = mode == 'denied'
            return process
        fake = SimpleNamespace(
            SBError=Error, eStateExited=3, eStateDetached=4, eStateStopped=1,
            eStateCrashed=2, eStopReasonException=9, eStopReasonSignal=10,
            SBCommandReturnObject=lambda: SimpleNamespace(GetOutput=lambda: 'fixture stack',
                                                         GetError=lambda: '',
                                                         Succeeded=lambda: mode != 'format-refusal'))
        debugger = SimpleNamespace(
            SetAsync=lambda value: calls.append(('async', value)),
            CreateTarget=lambda path: SimpleNamespace(AttachToProcessWithID=attach),
            GetListener=lambda: None,
            GetCommandInterpreter=lambda: SimpleNamespace(
                HandleCommand=lambda command, output: calls.append(command)))
        raw = (self.row['start'] + ' ' + self.row['command']).encode()
        def advance_fake_stop(_):
            calls.append('advance-stop-id')
            process.stop_id += 1
        with patch.dict('sys.modules', {'lldb': fake}), \
                patch.object(artifacts.time, 'sleep', side_effect=advance_fake_stop), \
                patch.object(artifacts.subprocess, 'check_output', return_value=raw), \
                patch('builtins.print'):
            artifacts.run_owned_fault_session(debugger, identity_path, self.hook.session,
                                              self.hook.cancel)
        return json.loads(self.hook.session.read_text()), calls

    def test_session_fault_capture_detaches_resuming_without_kill_or_expressions(self):
        result, calls = self.run_session('fault')
        self.assertEqual(result['status'], 'fault-captured')
        self.assertTrue(result['handedBack'])
        self.assertIn(('detach', False), calls)
        self.assertIn('thread backtrace all -c 64', calls)
        self.assertTrue(all(not (isinstance(c, str) and 'expression' in c) for c in calls))

    def test_session_denial_never_continues_or_detaches_invalid_process(self):
        result, calls = self.run_session('denied')
        self.assertEqual(result['status'], 'attach-denied')
        self.assertTrue(result['handedBack'])
        self.assertNotIn('continue', calls)
        self.assertNotIn(('detach', False), calls)

    def test_session_observer_exception_still_detaches_and_reports_failure(self):
        result, calls = self.run_session('exception')
        self.assertEqual(result['status'], 'observer-error')
        self.assertTrue(result['handedBack'])
        self.assertIn(('detach', False), calls)

    def test_session_natural_exit_does_not_detach_or_cleanup(self):
        result, calls = self.run_session('exit')
        self.assertEqual(result['status'], 'target-exited')
        self.assertTrue(result['handedBack'])
        self.assertNotIn(('detach', False), calls)

    def test_observer_start_failure_does_not_signal_unattached_helper(self):
        def missing_debugger(*args, **kwargs):
            raise FileNotFoundError('fixture missing debugger')
        self.hook.popen = missing_debugger
        self.start()
        result = self.hook.finish()
        self.assertEqual(result['status'], 'observer-start-failed')
        self.assertTrue(result['diagnosticallyInterrupted'])
        self.assertEqual(self.cleaned, [])

    def test_attach_stop_is_not_misclassified_as_a_new_fault(self):
        result, calls = self.run_session('stale-attach-stop')
        self.assertEqual(result['status'], 'fault-captured')
        self.assertIn('advance-stop-id', calls)
        self.assertLess(calls.index('advance-stop-id'), calls.index('thread backtrace all -c 64'))

    def test_live_observer_exec_transition_retains_current_cleanup_identity(self):
        self.observer_code = None
        self.start()
        self.rows[55]['command'] = 'fixture-lldb-after-xcrun-exec'
        self.hook.poll()
        self.hook._interrupt('fixture lifecycle failure')
        result = self.hook.finish()
        self.assertTrue(result['diagnosticallyInterrupted'])
        self.assertEqual(set(self.cleaned), {21, 55, 56})

    def test_reader_failure_cannot_leave_debugger_blocked_on_output(self):
        self.observer_code = None
        self.start()
        self.hook.result['readerError'] = 'fixture output failure'
        self.hook.poll()
        result = self.hook.finish()
        self.assertTrue(result['diagnosticallyInterrupted'])
        self.assertEqual(set(self.cleaned), {21, 55, 56})

    def test_minimal_formats_precede_attach_and_fault_output_without_extended_queries(self):
        result, calls = self.run_session('fault')
        settings = [call for call in calls if isinstance(call, str) and call.startswith('settings ')]
        self.assertEqual(len(settings), 3)
        expected = {
            'thread-format': {'thread.index', 'thread.id'},
            'thread-stop-format': {'thread.index', 'thread.id'},
            'frame-format': {'frame.index', 'frame.pc'},
        }
        import re
        for command in settings:
            name = command.split()[2]
            variables = set(re.findall(r'\$\{([^}]+)\}', command))
            self.assertEqual(variables, expected[name])
            self.assertLess(calls.index(command), calls.index(('attach', 21)))
            self.assertLess(calls.index(command), calls.index('thread backtrace all -c 64'))
        self.assertTrue(result['handedBack'])
        self.assertIn('register read', calls)
        self.assertIn('image list -u -f', calls)

    def test_format_refusal_stops_before_attachment_or_default_backtrace(self):
        result, calls = self.run_session('format-refusal')
        self.assertEqual(result['status'], 'observer-error')
        self.assertNotIn(('attach', 21), calls)
        self.assertNotIn('continue', calls)
        self.assertNotIn('thread backtrace all -c 64', calls)

    def test_session_failed_detach_is_never_claimed_handed_back(self):
        result, calls = self.run_session('detach-failure')
        self.assertEqual(result['status'], 'fault-captured')
        self.assertFalse(result['handedBack'])
        self.assertIn('detachError', result)


class CrashArtifactTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name).resolve()
        self.workspace = self.base / 'repo'
        self.image = self.workspace / '.build/debug/Sample.xctest/Contents/MacOS/Sample'
        self.image.parent.mkdir(parents=True)
        self.image.write_bytes(b'hosted-test-image\x00original')
        self.symbols = self.image.with_name('Sample.dSYM')
        self.dwarf = self.symbols / 'Contents/Resources/DWARF/Sample'
        self.dwarf.parent.mkdir(parents=True)
        self.dwarf.write_bytes(b'original-symbols')
        self.evidence = self.base / 'evidence'
        self.evidence.mkdir()
        self.reports = self.base / 'DiagnosticReports'
        self.reports.mkdir()
        self.start = datetime.now().replace(microsecond=0)
        self.row = {'start': self.start.strftime('%a %b %d %H:%M:%S %Y'),
                    'command': shlex.join(['/toolchain/swiftpm-testing-helper',
                                           '--test-bundle-path', str(self.image),
                                           '--testing-library', 'swift-testing'])}
        self.history = {21: [self.row], 22: [dict(self.row, command=shlex.join(
            ['/toolchain/dsymutil', str(self.image), '-o', str(self.symbols)]))]}
        self.uuid = {'arm64': '12345678-1234-1234-1234-123456789ABC'}

    def metadata(self, path):
        return {'uuids': self.uuid, 'fixtureOnly': True}

    def retain(self, budget=None, reader=None):
        return artifacts.retain_test_images(
            self.history, self.workspace, self.evidence, 'a' * 40,
            budget or artifacts.ArtifactBudget(), reader or self.metadata)

    def payload(self, **changes):
        value = {'pid': 21, 'procPath': '/toolchain/swiftpm-testing-helper',
                 'procLaunch': self.start.astimezone().isoformat()}
        value.update(changes)
        return value

    def collect(self, baseline, budget=None, observed_images=()):
        return artifacts.collect_reports(
            [self.reports], baseline, self.history, self.evidence,
            budget or artifacts.ArtifactBudget(), window=0, observed_images=observed_images)

    def test_owned_image_and_matching_symbols_keep_original_bytes_and_provenance(self):
        row = self.retain()[0]
        self.assertEqual(row['status'], 'retained-image')
        self.assertEqual(row['source'], 'a' * 40)
        self.assertEqual((row['pid'], row['start']), (21, self.row['start']))
        target = self.evidence / row['retainedImage']
        self.assertEqual(target.read_bytes(), self.image.read_bytes())
        self.assertEqual(row['imageSHA256'], artifacts.sha(target))
        symbols = row['symbols']
        self.assertEqual(symbols['status'], 'retained-matching-dsym')
        for relative, digest in symbols['files'].items():
            copied = self.evidence / symbols['retained'] / relative
            self.assertEqual(copied.read_bytes(), (self.symbols / relative).read_bytes())
            self.assertEqual(artifacts.sha(copied), digest)

    def test_compiler_filename_mentions_and_unobserved_files_are_not_capture_authority(self):
        history = {2: [dict(self.row, command='clang -o ' + str(self.image))]}
        self.assertEqual(artifacts.observed_test_images(history, self.workspace), [])
        self.assertEqual(artifacts.observed_test_images({}, self.workspace), [])

    def test_observed_argument_outside_build_is_rejected(self):
        outside = self.base / 'Outside.xctest/Contents/MacOS/Outside'
        outside.parent.mkdir(parents=True)
        outside.write_bytes(b'not workspace content')
        self.history[21][0]['command'] = shlex.join(
            ['/toolchain/swiftpm-testing-helper', '--test-bundle-path', str(outside)])
        self.assertEqual(self.retain()[0]['status'], 'refused-image')
        self.assertFalse((self.evidence / 'native-images').exists())

    def test_binary_symlink_escape_is_not_read_or_copied(self):
        outside = self.base / 'private-content'
        outside.write_bytes(b'unrelated')
        self.image.unlink()
        self.image.symlink_to(outside)
        self.assertEqual(self.retain()[0]['status'], 'refused-image')
        self.assertFalse((self.evidence / 'native-images').exists())

    def test_build_root_symlink_cannot_expand_workspace_capture(self):
        build = self.workspace / '.build'
        outside = self.base / 'external-build'
        build.rename(outside)
        build.symlink_to(outside, target_is_directory=True)
        self.assertEqual(self.retain()[0]['status'], 'refused-build-root')
        self.assertFalse((self.evidence / 'native-images').exists())

    def test_symbolic_report_root_is_not_listed(self):
        link = self.base / 'report-link'
        link.symlink_to(self.reports, target_is_directory=True)
        audit = artifacts.report_snapshot([link])
        self.assertEqual(audit['directories'][0]['status'], 'refused-symbolic-report-root')
        self.assertEqual(audit['candidates'], {})

    def test_symbol_symlink_escape_preserves_only_valid_image(self):
        outside = self.base / 'unrelated-symbols'
        outside.write_bytes(b'not attributable')
        self.dwarf.unlink()
        self.dwarf.symlink_to(outside)
        row = self.retain()[0]
        self.assertEqual(row['status'], 'retained-image')
        self.assertTrue((self.evidence / row['retainedImage']).is_file())
        self.assertEqual(row['symbols']['status'], 'symbol-retention-error')

    def test_symbol_uuid_mismatch_is_explicit_and_keeps_the_image(self):
        def different(path):
            return {'uuids': self.uuid if path == self.image else {'arm64': 'different'}}
        row = self.retain(reader=different)[0]
        self.assertEqual(row['status'], 'retained-image')
        self.assertEqual(row['symbols']['status'], 'missing-or-mismatched-uuid')
        self.assertFalse((self.evidence / 'native-images/0/Sample.dSYM').exists())

    def test_missing_symbols_are_reported_without_fabricating_an_image(self):
        shutil.rmtree(self.symbols)
        row = self.retain()[0]
        self.assertEqual(row['symbols']['status'], 'no-observed-dsym-producer')
        self.image.unlink()
        self.assertEqual(self.retain()[0]['status'], 'refused-image')

    def test_size_cap_prioritizes_image_and_never_truncates_symbols(self):
        budget = artifacts.ArtifactBudget(self.image.stat().st_size)
        row = self.retain(budget)[0]
        self.assertEqual(row['status'], 'retained-image')
        self.assertEqual(row['symbols']['status'], 'refused-size-cap')
        self.assertEqual((self.evidence / row['retainedImage']).read_bytes(), self.image.read_bytes())
        self.assertEqual(budget.used, self.image.stat().st_size)

    def test_all_images_precede_earlier_symbols_under_the_shared_cap(self):
        later = self.workspace / '.build/asan/Later.xctest/Contents/MacOS/Later'
        later.parent.mkdir(parents=True)
        later.write_bytes(b'later failing cohort image')
        self.history[31] = [dict(self.row, command=shlex.join(
            ['/toolchain/swiftpm-testing-helper', '--test-bundle-path', str(later)]))]
        budget = artifacts.ArtifactBudget(self.image.stat().st_size + later.stat().st_size)
        rows = self.retain(budget)
        self.assertEqual([row['status'] for row in rows], ['retained-image', 'retained-image'])
        self.assertEqual(rows[0]['symbols']['status'], 'refused-size-cap')
        self.assertEqual((self.evidence / rows[1]['retainedImage']).read_bytes(), later.read_bytes())
        self.assertEqual(budget.used, budget.limit)

    def test_growth_between_report_stat_and_hash_cannot_exceed_the_cap(self):
        baseline = artifacts.report_snapshot([self.reports])
        report = self.reports / 'growing.ips'
        raw = json.dumps(self.payload()).encode()
        report.write_bytes(raw)
        original_sha = artifacts.sha
        grown = False
        def grow_after_snapshot_stat(path):
            nonlocal grown
            if Path(path) == report and not grown:
                report.write_bytes(raw + b' ' * 1024)
                grown = True
            return original_sha(path)
        budget = artifacts.ArtifactBudget(len(raw) + 10)
        with patch.object(artifacts, 'sha', side_effect=grow_after_snapshot_stat):
            rows, _ = self.collect(baseline, budget)
        self.assertEqual(rows[0]['reason'], 'artifact-size-cap')
        self.assertGreater(rows[0]['bytes'], budget.limit)
        self.assertEqual(budget.used, 0)
        self.assertFalse((self.evidence / 'matched-crashes').exists())
        self.assertFalse((self.evidence / 'unattributed-helper-diagnostics').exists())

    def test_growth_during_report_read_is_rechecked_before_retention(self):
        baseline = artifacts.report_snapshot([self.reports])
        report = self.reports / 'read-growth.ips'
        raw = json.dumps(self.payload()).encode()
        report.write_bytes(raw)
        original_open = Path.open
        def grow_during_read(path, *args, **kwargs):
            if path == report and args == ('rb',):
                with original_open(report, 'wb') as stream:
                    stream.write(raw + b' ' * 1024)
            return original_open(path, *args, **kwargs)
        budget = artifacts.ArtifactBudget(len(raw) + 10)
        with patch.object(Path, 'open', grow_during_read):
            rows, _ = self.collect(baseline, budget)
        self.assertEqual(rows[0]['reason'], 'artifact-size-cap')
        self.assertGreater(rows[0]['bytes'], budget.limit)
        self.assertEqual(budget.used, 0)
        self.assertFalse((self.evidence / 'matched-crashes').exists())
        self.assertFalse((self.evidence / 'unattributed-helper-diagnostics').exists())

    def test_oversized_image_is_refused_without_partial_output(self):
        row = self.retain(artifacts.ArtifactBudget(1))[0]
        self.assertEqual(row['status'], 'refused-image-size-cap')
        self.assertFalse((self.evidence / 'native-images').exists())

    def test_uuid_tool_failure_is_metadata_not_a_native_test_invocation(self):
        with patch.object(artifacts.subprocess, 'run', return_value=SimpleNamespace(
                returncode=1, stdout='', stderr='fixture tool refusal')) as run:
            metadata = artifacts.image_uuids(self.image)
        self.assertEqual(metadata['uuids'], {})
        self.assertEqual(run.call_args.args[0][:3], ['xcrun', 'dwarfdump', '--uuid'])
        with patch.object(artifacts.subprocess, 'run', side_effect=subprocess.TimeoutExpired('uuid', 10)):
            self.assertIn('error', artifacts.image_uuids(self.image))

    def test_modern_multiple_document_report_retains_exact_original(self):
        baseline = artifacts.report_snapshot([self.reports])
        original = self.reports / 'helper.ips'
        data = (json.dumps({'header': 'fixture'}) + '\n' + json.dumps(self.payload())).encode()
        original.write_bytes(data)
        rows, audit = self.collect(baseline)
        self.assertTrue(rows[0]['matchedActualProcess'])
        self.assertEqual((self.evidence / rows[0]['retained']).read_bytes(), data)
        self.assertEqual(rows[0]['sha256'], hashlib.sha256(data).hexdigest())
        self.assertEqual(audit['observations'][0]['directories'][0]['formats'], {'.ips': 1})

    def test_legacy_report_requires_observed_pid_path_and_launch(self):
        baseline = artifacts.report_snapshot([self.reports])
        data = ('Process: swiftpm-testing-helper [21]\nPath: /toolchain/swiftpm-testing-helper\n'
                'Launch Time: ' + self.start.astimezone().isoformat() + '\nThread fixture\n').encode()
        (self.reports / 'helper.crash').write_bytes(data)
        rows, _ = self.collect(baseline)
        self.assertTrue(rows[0]['matchedActualProcess'])
        self.assertEqual((self.evidence / rows[0]['retained']).read_bytes(), data)

    def test_unrelated_reused_pid_missing_launch_and_malformed_reports_are_metadata_only(self):
        baseline = artifacts.report_snapshot([self.reports])
        wrong = [self.payload(pid=22), self.payload(procPath='/unrelated/app'),
                 self.payload(procLaunch=(self.start - timedelta(days=1)).astimezone().isoformat())]
        for index, payload in enumerate(wrong):
            (self.reports / f'unrelated{index}.ips').write_text(json.dumps(payload))
        (self.reports / 'missing.crash').write_text(
            'Process: helper [21]\nPath: /toolchain/swiftpm-testing-helper\n')
        (self.reports / 'partial.ips').write_text('{')
        rows, _ = self.collect(baseline)
        self.assertEqual(len(rows), 5)
        self.assertTrue(all(not row['matchedActualProcess'] for row in rows))
        self.assertFalse((self.evidence / 'matched-crashes').exists())

    def test_report_symlink_escape_is_only_a_refusal(self):
        baseline = artifacts.report_snapshot([self.reports])
        outside = self.base / 'unrelated.ips'
        outside.write_text(json.dumps(self.payload()))
        (self.reports / 'escape.ips').symlink_to(outside)
        rows, _ = self.collect(baseline)
        self.assertEqual(len(rows), 1)
        self.assertIn('error', rows[0])
        self.assertNotIn('sha256', rows[0])
        self.assertFalse((self.evidence / 'matched-crashes').exists())

    def test_missing_and_unreadable_roots_and_unchanged_baseline_are_explicit(self):
        missing = artifacts.report_snapshot([self.base / 'absent'])
        self.assertEqual(missing['directories'][0]['status'], 'absent')
        with patch.object(Path, 'iterdir', side_effect=PermissionError('fixture denial')):
            denied = artifacts.report_snapshot([self.reports])
        self.assertEqual(denied['directories'][0]['status'], 'unavailable')
        (self.reports / 'existing.ips').write_text(json.dumps(self.payload()))
        rows, _ = self.collect(artifacts.report_snapshot([self.reports]))
        self.assertEqual(rows, [])

    def test_missing_identity_helper_original_is_unattributed_with_exact_bytes_and_budget(self):
        images = self.retain()
        baseline = artifacts.report_snapshot([self.reports])
        report = self.reports / '.swiftpm-testing-helper-2026-10-20-210144.ips'
        raw = json.dumps({'diagnostic': 'fixture with no identity'}).encode()
        report.write_bytes(raw)
        budget = artifacts.ArtifactBudget(len(raw))
        rows, _ = self.collect(baseline, budget, images)
        self.assertFalse(rows[0]['matchedActualProcess'])
        self.assertEqual(rows[0]['attribution'], 'unproved')
        self.assertEqual(rows[0]['identity'], dict(pid=None, procPath=None, procLaunch=None))
        self.assertEqual(rows[0]['observedContext'][0]['pid'], 21)
        self.assertTrue(rows[0]['retained'].startswith('unattributed-helper-diagnostics/'))
        self.assertEqual((self.evidence / rows[0]['retained']).read_bytes(), raw)
        self.assertEqual(rows[0]['sha256'], hashlib.sha256(raw).hexdigest())
        self.assertEqual(budget.used, len(raw))
        self.assertFalse((self.evidence / 'matched-crashes').exists())

    def test_malformed_helper_original_remains_unproved_without_parser_repair(self):
        images = self.retain()
        baseline = artifacts.report_snapshot([self.reports])
        report = self.reports / 'swiftpm-testing-helper-2026-10-20-210144.ips'
        raw = json.dumps(self.payload()).encode() + b'\n{unfinished original'
        report.write_bytes(raw)
        rows, _ = self.collect(baseline, observed_images=images)
        self.assertFalse(rows[0]['matchedActualProcess'])
        self.assertEqual(rows[0]['identity'], dict(pid=None, procPath=None, procLaunch=None))
        self.assertEqual((self.evidence / rows[0]['retained']).read_bytes(), raw)
        self.assertFalse((self.evidence / 'matched-crashes').exists())

    def test_helper_family_without_an_owned_retained_cohort_is_metadata_only(self):
        image = self.retain()[0]
        baseline = artifacts.report_snapshot([self.reports])
        report = self.reports / '.swiftpm-testing-helper-2026-10-20-210144.ips'
        report.write_bytes(b'{}')
        for images in [[], [dict(image, status='refused-image-size-cap')],
                       [dict(image, pid=99)], [dict(image, start='not the observed start')],
                       [dict(image, retainedImage=None)],
                       [dict(image, retainedImage='missing-retained-image')],
                       [dict(image, arguments=['/unobserved/swiftpm-testing-helper'])]]:
            with self.subTest(images=images):
                rows, _ = self.collect(baseline, observed_images=images)
                self.assertFalse(rows[0]['matchedActualProcess'])
                self.assertNotIn('retained', rows[0])
        self.assertFalse((self.evidence / 'unattributed-helper-diagnostics').exists())

    def test_unrelated_names_and_unchanged_helper_baseline_do_not_expand_capture(self):
        images = self.retain()
        report = self.reports / '.swiftpm-testing-helper-2026-10-20-210144.ips'
        report.write_bytes(b'{}')
        baseline = artifacts.report_snapshot([self.reports])
        (self.reports / 'another-app-2026-10-20-210144.ips').write_bytes(b'{}')
        (self.reports / '.swiftpm-testing-helper-unproved-name.ips').write_bytes(b'{}')
        rows, _ = self.collect(baseline, observed_images=images)
        self.assertEqual(len(rows), 2)
        self.assertTrue(all(not row['matchedActualProcess'] and 'retained' not in row for row in rows))
        baseline['candidates'][str(report)].pop('sha256')
        rows, _ = self.collect(baseline, observed_images=images)
        self.assertEqual(len(rows), 3)
        self.assertTrue(all(not row['matchedActualProcess'] and 'retained' not in row for row in rows))
        self.assertFalse((self.evidence / 'unattributed-helper-diagnostics').exists())

    def test_conflicting_helper_identity_remains_unattributed_including_pid_reuse(self):
        images = self.retain()
        baseline = artifacts.report_snapshot([self.reports])
        values = [self.payload(pid=22), self.payload(procPath='/unrelated/app'),
                  self.payload(procLaunch=(self.start - timedelta(days=1)).astimezone().isoformat())]
        originals = {}
        for index, value in enumerate(values):
            name = f'.swiftpm-testing-helper-2026-10-20-21014{index}.ips'
            originals[name] = json.dumps(value).encode()
            (self.reports / name).write_bytes(originals[name])
        rows, _ = self.collect(baseline, observed_images=images)
        self.assertEqual(len(rows), 3)
        for row in rows:
            self.assertFalse(row['matchedActualProcess'])
            self.assertEqual(row['attribution'], 'unproved')
            self.assertEqual((self.evidence / row['retained']).read_bytes(), originals[row['name']])
        self.assertFalse((self.evidence / 'matched-crashes').exists())

    def test_poll_deduplication_and_later_exact_attribution_charge_original_once(self):
        images = self.retain()
        baseline = artifacts.report_snapshot([self.reports])
        report = self.reports / '.swiftpm-testing-helper-2026-10-20-210144.ips'
        raw = json.dumps(self.payload(pid=23)).encode()
        report.write_bytes(raw)
        budget = artifacts.ArtifactBudget(len(raw))
        snapshot = artifacts.report_snapshot
        calls = 0

        def observe(roots):
            nonlocal calls
            calls += 1
            if calls == 3:
                self.history[23] = [dict(self.row)]
            return snapshot(roots)

        with patch.object(artifacts, 'report_snapshot', side_effect=observe), \
                patch.object(artifacts.time, 'monotonic', side_effect=[0, 0, 0, 0.5, 0.5, 1, 1, 1]), \
                patch.object(artifacts.time, 'sleep'):
            rows, _ = artifacts.collect_reports(
                [self.reports], baseline, self.history, self.evidence, budget,
                window=1, observed_images=images)
        self.assertEqual(calls, 3)
        self.assertTrue(rows[0]['matchedActualProcess'])
        self.assertEqual(rows[0]['attribution'], 'proved-pid-start-path')
        self.assertTrue(rows[0]['retained'].startswith('matched-crashes/'))
        self.assertTrue(rows[0]['promotedFrom'].startswith('unattributed-helper-diagnostics/'))
        self.assertFalse((self.evidence / rows[0]['promotedFrom']).exists())
        self.assertEqual((self.evidence / rows[0]['retained']).read_bytes(), raw)
        self.assertEqual(budget.used, len(raw))

    def test_changed_then_disappearing_report_keeps_prior_original_with_cap_refusal(self):
        images = self.retain()
        baseline = artifacts.report_snapshot([self.reports])
        report = self.reports / '.swiftpm-testing-helper-2026-10-20-210144.ips'
        raw = b'{"original":"fixture"}'
        report.write_bytes(raw)
        budget = artifacts.ArtifactBudget(len(raw))
        snapshot = artifacts.report_snapshot
        calls = 0

        def observe(roots):
            nonlocal calls
            calls += 1
            if calls == 2:
                report.write_bytes(raw + b' ' * 100)
            elif calls == 3:
                report.unlink()
            return snapshot(roots)

        with patch.object(artifacts, 'report_snapshot', side_effect=observe), \
                patch.object(artifacts.time, 'monotonic', side_effect=[0, 0, 0, 0.5, 0.5, 1, 1, 1]), \
                patch.object(artifacts.time, 'sleep'):
            rows, _ = artifacts.collect_reports(
                [self.reports], baseline, self.history, self.evidence, budget,
                window=1, observed_images=images)
        self.assertEqual(rows[0]['reason'], 'artifact-size-cap')
        self.assertFalse(rows[0]['matchedActualProcess'])
        version = rows[0]['retainedVersions'][0]
        self.assertEqual(version['sha256'], hashlib.sha256(raw).hexdigest())
        self.assertFalse(version['matchedActualProcess'])
        self.assertEqual((self.evidence / version['retained']).read_bytes(), raw)
        self.assertEqual(budget.used, len(raw))

    def test_two_roots_share_one_original_and_all_references_follow_genuine_promotion(self):
        images = self.retain()
        system_reports = self.base / 'SystemDiagnosticReports'
        system_reports.mkdir()
        roots = [self.reports, system_reports]
        baseline = artifacts.report_snapshot(roots)
        name = '.swiftpm-testing-helper-2026-10-20-210144.ips'
        first = self.reports / name
        second = system_reports / name
        raw = json.dumps(self.payload(pid=23)).encode()
        first.write_bytes(raw)
        second.write_bytes(raw)
        budget = artifacts.ArtifactBudget(len(raw) * 2)
        snapshot = artifacts.report_snapshot
        calls = 0

        def observe(current_roots):
            nonlocal calls
            calls += 1
            if calls == 2:
                self.history[23] = [dict(self.row)]
            elif calls == 3:
                first.write_bytes(raw + b' ' * (budget.limit + 1))
                second.unlink()
            return snapshot(current_roots)

        with patch.object(artifacts, 'report_snapshot', side_effect=observe), \
                patch.object(artifacts.time, 'monotonic', side_effect=[0, 0, 0, 0.5, 0.5, 1, 1, 1]), \
                patch.object(artifacts.time, 'sleep'):
            rows, _ = artifacts.collect_reports(
                roots, baseline, self.history, self.evidence, budget,
                window=1, observed_images=images)
        self.assertEqual(calls, 3)
        self.assertEqual(len(rows), 2)
        changed = next(row for row in rows if row['directory'] == str(self.reports))
        disappeared = next(row for row in rows if row['directory'] == str(system_reports))
        self.assertEqual(changed['reason'], 'artifact-size-cap')
        self.assertFalse(changed['matchedActualProcess'])
        self.assertNotIn('retained', changed)
        self.assertEqual(len(changed['retainedVersions']), 1)
        self.assertTrue(disappeared['matchedActualProcess'])
        self.assertEqual(disappeared['attribution'], 'proved-pid-start-path')
        references = [row for row in rows if 'retained' in row]
        references += [version for row in rows for version in row.get('retainedVersions', [])]
        self.assertEqual(len(references), 2)
        self.assertEqual(len({row['retained'] for row in references}), 1)
        for row in references:
            self.assertTrue(row['matchedActualProcess'])
            self.assertTrue(row['retained'].startswith('matched-crashes/'))
            self.assertEqual(row['sha256'], hashlib.sha256(raw).hexdigest())
            self.assertEqual((self.evidence / row['retained']).read_bytes(), raw)
            self.assertNotIn('error', row)
        self.assertTrue(all('error' not in row for row in rows))
        self.assertFalse(any((self.evidence / 'unattributed-helper-diagnostics').iterdir()))
        self.assertEqual(budget.used, len(raw))


if __name__ == '__main__':
    unittest.main()
