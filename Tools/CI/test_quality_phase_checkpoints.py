"""Fake-process phase recovery: never launch native code from these unit cases."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

import quality_phase_checkpoints as runner


class QualityPhaseTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.bins = self.root / 'bin'
        self.image = self.bins / 'Tests.xctest/Contents/MacOS/Tests'
        self.image.parent.mkdir(parents=True)
        self.image.write_bytes(b'fake test image')
        (self.bins / 'Elite').write_bytes(b'fake application image')
        (self.bins / 'codecov').mkdir()
        (self.bins / 'codecov/default.profdata').write_bytes(b'fake profile')
        self.methods = ['EliteCoreTests.First/one()', 'EliteCoreTests.Second/two()']
        self.head = 'a' * 40
        self.calls = []
        self.fail_leaks = True
        self.fail_converter = False
        self.fail_native = False

    def output(self, command, *_):
        if command[:2] == ['git', 'rev-parse']:
            return self.head
        if command[:2] == ['git', 'status']:
            return ''
        if '--show-bin-path' in command:
            return str(self.bins)
        if 'list' in command:
            return '\n'.join(self.methods)
        return 'fixed toolchain/SDK identity'

    def fake_run(self, command, **options):
        self.assertTrue(options['pass_fds'])
        self.assertTrue(options['start_new_session'])
        self.calls.append(command)
        code = 0
        if command[1] == 'test':
            report = Path(command[command.index('--xunit-output') + 1]).with_name('tests-swift-testing.xml')
            root = ET.Element('testsuites')
            suite = ET.SubElement(root, 'testsuite', tests='2', failures='0', errors='0', skipped='0')
            for raw in self.methods:
                classname, name = raw.split('/')
                ET.SubElement(suite, 'testcase', classname=classname, name=name, time='1')
            ET.ElementTree(root).write(report)
            options['stdout'].write(b'Complete fake normal run\n')
            code = 5 if self.fail_native else 0
        elif command[0] == '/usr/bin/leaks':
            options['stdout'].write(b'1 leaks for 16 total leaked bytes\n' if self.fail_leaks
                                    else b'0 leaks for 0 total leaked bytes\n')
            code = 2 if self.fail_leaks else 0
        elif 'lcov-to-sonarqube-generic.py' in command[1]:
            code = 7 if self.fail_converter else 0
            root = ET.Element('coverage', version='1')
            file = ET.SubElement(root, 'file', path='Sources/fake.swift')
            for line in range(5):
                ET.SubElement(file, 'lineToCover', lineNumber=str(line + 1), covered='true')
            ET.ElementTree(root).write(command[3])
        elif command[:3] == ['xcrun', 'llvm-cov', 'export']:
            options['stdout'].write(b'fake lcov\n')
        return subprocess.CompletedProcess(command, code)

    def context(self):
        from contextlib import ExitStack
        stack = ExitStack()
        # Fake phases must not consume the physical runner's one-off authorization.
        stack.enter_context(patch.dict(os.environ, {'ELITE_NATIVE_POLICY': ''}))
        stack.enter_context(patch.object(runner, 'ROOT', self.root))
        stack.enter_context(patch.object(runner, 'output', side_effect=self.output))
        stack.enter_context(patch.object(runner, 'executable_inputs', return_value={'Sources/fake.swift': 'fixed'}))
        stack.enter_context(patch.object(runner, 'ensure_no_live_tests'))
        stack.enter_context(patch.object(runner, 'opt_in_policy', return_value={'expected_skips': []}))
        stack.enter_context(patch.object(runner.shutil, 'which', return_value='/toolchain/swift'))
        stack.enter_context(patch.object(runner.subprocess, 'run', side_effect=self.fake_run))
        return stack

    def test_later_leak_failure_keeps_normal_success_and_retry_does_not_repeat_tests(self):
        with self.context():
            runner.run_phase('normal', self.root / 'cache')
            with self.assertRaisesRegex(ValueError, 'phase failed'):
                runner.run_phase('leaks', self.root / 'cache')
            self.head = 'b' * 40  # Docs-only commit, exact same executable inputs and image.
            (self.root / 'coverage.xml').unlink()
            runner.run_phase('normal', self.root / 'cache')
            self.fail_leaks = False
            runner.run_phase('leaks', self.root / 'cache')
        self.assertEqual(sum(command[1] == 'test' for command in self.calls), 1)
        self.assertEqual(sum(command[0] == '/usr/bin/leaks' for command in self.calls), 2)
        summaries = [json.loads(p.read_text()) for p in self.root.glob('reports/quality-phases/normal/*/summary.json')]
        resumed = next(row for row in summaries if row['reused'])
        self.assertEqual((resumed['tested_head'], resumed['current_head']), ('a' * 40, 'b' * 40))
        self.assertEqual(resumed['executed_test_wall_seconds'], 0)
        self.assertTrue((self.root / 'coverage.xml').exists())
        self.assertIn('0 leaks', (self.root / 'reports/leaks.txt').read_text())

    def test_generated_root_profile_is_clean_but_maintained_source_is_rejected(self):
        real_run = subprocess.run

        def git(*arguments):
            return real_run(['git', *arguments], cwd=self.root, check=True,
                            capture_output=True, text=True).stdout.strip()

        (self.root / '.gitignore').write_text(
            (Path(__file__).resolve().parents[2] / '.gitignore').read_text()
            + '\n/bin/\n/cache/\n')
        source = self.root / 'Sources/fake.swift'
        source.parent.mkdir()
        source.write_text('// maintained source\n')
        git('init', '-q')
        git('add', '.gitignore', 'Sources/fake.swift')
        git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
            '-c', 'commit.gpgsign=false', 'commit', '-qm', 'test: create fixture')

        def output(command, *arguments):
            if command[0] == 'git':
                return git(*command[1:])
            return self.output(command, *arguments)

        def native_with_profile(command, **options):
            result = self.fake_run(command, **options)
            if command[1] == 'test':
                (self.root / 'default.profraw').write_bytes(b'generated LLVM profile')
            return result

        with self.context(), patch.object(runner, 'output', side_effect=output), \
                patch.object(runner.subprocess, 'run', side_effect=native_with_profile):
            runner.run_phase('normal', self.root / 'cache')
            self.assertEqual(git('status', '--porcelain'), '')
            for name in ('Sources/fake.swift', 'Sources/untracked.swift', 'Sources/default.profraw'):
                with self.subTest(path=name):
                    path = self.root / name
                    original = path.read_bytes() if path.exists() else None
                    path.write_bytes(b'changed maintained input')
                    self.assertTrue(git('status', '--porcelain'))
                    with self.assertRaisesRegex(ValueError, 'clean committed checkout'):
                        runner.run_phase('normal', self.root / 'cache')
                    if original is None:
                        path.unlink()
                    else:
                        path.write_bytes(original)
        self.assertEqual(sum(command[1] == 'test' for command in self.calls), 1)

    def test_one_off_attestation_exports_coverage_without_copying_or_reexecuting_prior_pass(self):
        with self.context():
            runner.run_phase('normal', self.root / 'cache')
            attempt = next((self.root / 'cache/phases').glob('*/*/result.json')).parent
            result = json.loads((attempt / 'result.json').read_text())
            original = (attempt / 'result.json').read_bytes()
            self.head = 'b' * 40
            attestation = {'status': 'attested-from-prior-execution', 'tested_head': result['tested_head'],
                           'qualified_head': self.head, 'new_test_execution_seconds': 0}
            with patch('m01_normal_attestation.qualify', return_value=(attempt, result, attestation)):
                runner.run_phase('normal', self.root / 'cache')
        report = next(path.parent for path in self.root.glob('reports/quality-phases/normal/*/attestation.json'))
        summary = json.loads((report / 'summary.json').read_text())
        self.assertTrue(summary['attested'])
        self.assertFalse(summary['reused'])
        self.assertEqual(summary['executed_test_wall_seconds'], 0)
        self.assertEqual((summary['tested_head'], summary['current_head']), ('a' * 40, 'b' * 40))
        self.assertFalse((report / 'completed').exists())
        self.assertEqual((attempt / 'result.json').read_bytes(), original)
        self.assertEqual(sum(command[1] == 'test' for command in self.calls), 1)
        self.assertTrue((self.root / 'coverage.xml').is_file())

    def test_changed_image_environment_and_tampered_output_refuse_reuse(self):
        with self.context():
            runner.run_phase('normal', self.root / 'cache')
            attempt = next((self.root / 'cache/phases').glob('*/*/result.json')).parent
            identity = json.loads((attempt / 'result.json').read_text())['identity']
            self.assertIsNotNone(runner.successful_phase(attempt, identity))
            changed = {**identity, 'environment': {'ELITE_DIAGNOSTIC': 'changed'}}
            self.assertIsNone(runner.successful_phase(attempt, changed))
            report = attempt / 'coverage.xml'
            report.chmod(0o600)
            report.write_text('<coverage/>')
            self.assertIsNone(runner.successful_phase(attempt, identity))
            self.image.write_bytes(b'new image identity')
            runner.run_phase('normal', self.root / 'cache')
        self.assertEqual(sum(command[1] == 'test' for command in self.calls), 2)

    def test_successful_test_then_converter_failure_keeps_native_exit_and_terminal_stage(self):
        self.fail_converter = True
        with self.context(), self.assertRaisesRegex(ValueError, 'phase failed'):
            runner.run_phase('normal', self.root / 'cache')
        result = json.loads(next((self.root / 'cache/phases').glob('*/*/result.json')).read_text())
        self.assertEqual(result['native_exit_code'], 0)
        self.assertEqual(result['exit_code'], 7)
        self.assertEqual(result['failure_kind'], 'coverage-tool')
        self.assertIn('lcov-to-sonarqube-generic.py', result['failed_command'][1])
        self.assertGreaterEqual(result['phase_wall_seconds'], result['test_wall_seconds'])
        self.assertIsNone(runner.successful_phase(next((self.root / 'cache/phases').glob('*/*')), result['identity']))

    def test_failed_native_process_with_complete_xml_cannot_be_reused(self):
        self.fail_native = True
        with self.context(), self.assertRaisesRegex(ValueError, 'phase failed'):
            runner.run_phase('normal', self.root / 'cache')
        file = next((self.root / 'cache/phases').glob('*/*/result.json'))
        result = json.loads(file.read_text())
        self.assertEqual(result['native_exit_code'], 5)
        self.assertEqual(result['failure_kind'], 'test-process')
        self.assertIsNone(runner.successful_phase(file.parent, result['identity']))

    def test_failed_build_has_no_test_time_and_retains_original_status(self):
        def refusal(command, **options):
            return subprocess.CompletedProcess(command, 9)
        with self.context(), patch.object(runner.subprocess, 'run', side_effect=refusal):
            with self.assertRaises(subprocess.CalledProcessError):
                runner.run_phase('normal', self.root / 'cache')
        result = json.loads(next(self.root.glob('reports/quality-phases/normal/*/phase-failure.json')).read_text())
        self.assertEqual(result['exit_code'], 9)
        self.assertEqual(result['failure_kind'], 'build')
        self.assertIsNone(result['test_wall_seconds'])

    def test_reusable_evidence_refuses_links_changed_receipts_and_missing_xml(self):
        with self.context():
            runner.run_phase('normal', self.root / 'cache')
        file = next((self.root / 'cache/phases').glob('*/*/result.json'))
        result = json.loads(file.read_text())
        attempt = file.parent
        attempt.chmod(0o700)
        report = attempt / 'tests-swift-testing.xml'
        report.rename(attempt / 'retained.xml')
        self.assertIsNone(runner.successful_phase(attempt, result['identity']))
        report.symlink_to(attempt / 'retained.xml')
        self.assertIsNone(runner.successful_phase(attempt, result['identity']))
        report.unlink()
        (attempt / 'retained.xml').rename(report)
        file.chmod(0o600)
        file.write_text(json.dumps({**result, 'exit_code': 2}))
        self.assertIsNone(runner.successful_phase(attempt, result['identity']))

    def test_extra_xctest_report_must_be_truly_empty_including_declared_counts(self):
        with self.context():
            runner.run_phase('normal', self.root / 'cache')
        file = next((self.root / 'cache/phases').glob('*/*/result.json'))
        result = json.loads(file.read_text())
        attempt = file.parent
        attempt.chmod(0o700)
        for content in ['<testsuite tests="1" failures="1"/>', '<testsuite errors="1"/>',
                        '<testsuite skipped="1"/>', '<testsuite disabled="1"/>',
                        '<testsuite><skipped/></testsuite>', '<unexpected/>']:
            (attempt / 'tests.xml').write_text(content)
            with self.subTest(content=content), self.assertRaises(ValueError):
                runner.validate_outputs(attempt, result['identity'])
        (attempt / 'tests.xml').write_text('<testsuites><testsuite tests="0" failures="0" errors="0"/></testsuites>')
        self.assertEqual(runner.validate_outputs(attempt, result['identity'])['percent'], 100)

    def test_leak_and_coverage_validators_do_not_accept_empty_or_failed_reports(self):
        for text in ['', 'process ended', '1 leaks for 8 total leaked bytes',
                     '0 leaks for 0 total leaked bytes\n1 leaks for 8 total leaked bytes']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                runner.validate_leaks(text)
        runner.validate_leaks('Process 42: 0 leaks for 0 total leaked bytes.')
        file = self.root / 'coverage.xml'
        for content in ['<coverage/>', '<coverage><file path="../foreign"><lineToCover covered="true"/></file></coverage>',
                        '<coverage><file path="Sources/fake.swift"><lineToCover covered="false"/></file></coverage>']:
            file.write_text(content)
            with self.assertRaises(ValueError):
                runner.validate_coverage(file, {'Sources/fake.swift': 'fixed'})


if __name__ == '__main__':
    unittest.main()
