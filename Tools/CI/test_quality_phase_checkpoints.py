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
        (self.bins / 'L337').write_bytes(b'fake application image')
        (self.bins / 'codecov').mkdir()
        (self.bins / 'codecov/default.profdata').write_bytes(b'fake profile')
        self.methods = ['L337CoreTests.First/one()', 'L337CoreTests.Second/two()']
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
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith(('GITHUB_', 'RUNNER_', 'ELITE_NATIVE_', 'ELITE_RECOVERABLE_'))}
        stack.enter_context(patch.dict(os.environ, environment, clear=True))
        stack.enter_context(patch.object(runner, 'ROOT', self.root))
        stack.enter_context(patch.object(runner, 'output', side_effect=self.output))
        stack.enter_context(patch.object(runner, 'executable_inputs', return_value={'Sources/fake.swift': 'fixed'}))
        stack.enter_context(patch.object(runner, 'ensure_no_live_tests'))
        stack.enter_context(patch.object(runner, 'opt_in_policy', return_value={'expected_skips': []}))
        stack.enter_context(patch.object(runner.shutil, 'which', return_value='/toolchain/swift'))
        stack.enter_context(patch.object(runner.subprocess, 'run', side_effect=self.fake_run))
        return stack

    def test_fake_phase_context_isolates_and_restores_native_job_authorization(self):
        physical = dict(GITHUB_ACTIONS='true', GITHUB_JOB='native_checks', GITHUB_RUN_ID='123',
                        ELITE_NATIVE_POLICY='/physical/policy.json', ELITE_NATIVE_APPROVED_HEAD='f' * 40,
                        ELITE_RECOVERABLE_POLICY_SHA256='e' * 64)
        with patch.dict(os.environ, physical):
            original_path = os.environ.get('PATH')
            with self.context():
                self.assertEqual(os.environ.get('PATH'), original_path)
                self.assertFalse(any(key in os.environ for key in physical))
                self.fail_leaks = False
                runner.run_phase('normal', self.root / 'cache')
                runner.run_phase('leaks', self.root / 'cache')
            for key, value in physical.items():
                self.assertEqual(os.environ[key], value)
        self.assertEqual(sum(command[1] == 'test' for command in self.calls), 1)
        self.assertEqual(sum(command[0] == '/usr/bin/leaks' for command in self.calls), 1)

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




class OwnedPhaseBuildTests(unittest.TestCase):
    setUp = QualityPhaseTests.setUp
    context = QualityPhaseTests.context
    output = QualityPhaseTests.output
    fake_run = QualityPhaseTests.fake_run

    def profile(self, phase):
        return dict(kind='owned-phase-build-v1', phase=phase, profile='jobs1-nonbatch-v1',
                    policy_sha256='c' * 64,
                    admission=dict(explicit=1, cpu_budget=1, ram_capacity=8, ram_reserve=2,
                                   peak_per_worker=2 if phase == 'normal' else 3,
                                   disk_capacity=100, disk_reserve=10, disk_per_worker=20),
                    flags=['--jobs', '1', '-Xswiftc', '-disable-batch-mode'])

    def test_explicit_sdk_queries_bind_each_actual_phase_identity_with_broken_defaults(self):
        self.fail_leaks = False
        for phase in ('normal', 'leaks'):
            with self.subTest(phase=phase):
                queries = []

                def query(command, *args):
                    queries.append(command)
                    if command in (['xcrun', '--show-sdk-path'], ['xcrun', '--show-sdk-version']):
                        raise subprocess.CalledProcessError(1, command, stderr='broken default SDK')
                    if command == ['xcrun', '--sdk', 'macosx', '--show-sdk-version']:
                        return 'explicit-sdk-fixture'
                    if command == ['xcrun', '--sdk', 'macosx', '--show-sdk-path']:
                        return '/fixture/explicit-macos.sdk'
                    return self.output(command, *args)

                cache = self.root / ('sdk-identity-' + phase)
                with self.context(), patch.dict(os.environ, {'GITHUB_SHA': self.head}), \
                        patch.object(runner, 'reviewed_build_profile', return_value=self.profile(phase)), \
                        patch.object(runner, 'output', side_effect=query):
                    runner.run_phase(phase, cache, '/owned/policy', 'f' * 64)
                result = json.loads(next(cache.glob('phases/*/*/result.json')).read_text())
                self.assertEqual(result['status'], 'passed')
                self.assertEqual(result['identity']['sdk'], 'explicit-sdk-fixture')
                self.assertEqual(result['identity']['sdk_path'], '/fixture/explicit-macos.sdk')
                for flag in ('--show-sdk-path', '--show-sdk-version'):
                    self.assertIn(['xcrun', '--sdk', 'macosx', flag], queries)

    def test_explicit_sdk_query_failure_cannot_qualify_normal_or_leaks(self):
        for phase in ('normal', 'leaks'):
            for index, flag in enumerate(('--show-sdk-path', '--show-sdk-version')):
                with self.subTest(phase=phase, command=flag):
                    rejected = ['xcrun', '--sdk', 'macosx', flag]
                    queries = []

                    def query(command, *args):
                        queries.append(command)
                        if command in (rejected, ['xcrun', '--show-sdk-path'],
                                       ['xcrun', '--show-sdk-version']):
                            raise subprocess.CalledProcessError(1, command, stderr='SDK unavailable')
                        return self.output(command, *args)

                    cache = self.root / ('sdk-refusal-' + phase + '-' + str(index))
                    with self.context(), patch.dict(os.environ, {'GITHUB_SHA': self.head}), \
                            patch.object(runner, 'reviewed_build_profile', return_value=self.profile(phase)), \
                            patch.object(runner, 'output', side_effect=query):
                        with self.assertRaises(subprocess.CalledProcessError):
                            runner.run_phase(phase, cache, '/owned/policy', 'f' * 64)
                    self.assertIn(rejected, queries)
                    self.assertFalse(list(cache.glob('phases/*/*/result.json')))
                    self.assertFalse(list((self.root / 'reports').glob('quality-phases/*/*/summary.json')))

    def test_each_phase_changes_only_build_argv_and_seals_its_actual_log_and_profile(self):
        self.fail_leaks = False
        for phase in ('normal', 'leaks'):
            profile = self.profile(phase)
            self.calls = []
            with self.context(), patch.dict(os.environ, {'GITHUB_SHA': self.head}), \
                    patch.object(runner, 'reviewed_build_profile', return_value=profile) as reviewed, \
                    patch('m01_normal_attestation.qualify') as old_attestation:
                runner.run_phase(phase, self.root / ('owned-' + phase), '/owned/policy', 'f' * 64)
            self.assertEqual(reviewed.call_count, 2)
            old_attestation.assert_not_called()
            build = self.calls[0]
            expected = ['/toolchain/swift', 'build']
            expected += ['--build-tests', '--enable-code-coverage'] if phase == 'normal' else []
            self.assertEqual(build, expected + profile['flags'])
            result = json.loads(next((self.root / ('owned-' + phase)).glob('phases/*/*/result.json')).read_text())
            self.assertEqual(result['identity']['build_profile'], {**profile, 'argv': build})
            self.assertIn('build.log', result['outputs'])
            if phase == 'normal':
                test = next(c for c in self.calls if c[1] == 'test')
                self.assertEqual(test[:4], ['/toolchain/swift', 'test', '--enable-code-coverage', '--skip-build'])
                self.assertNotIn('--jobs', test)
                self.assertNotIn('--no-parallel', test)
                self.assertEqual(result['validation']['percent'], 100.0)
            else:
                leak = next(c for c in self.calls if c[0] == '/usr/bin/leaks')
                self.assertEqual(leak, ['/usr/bin/leaks', '--atExit', '--', str(self.bins / 'L337'), '--diagnostics'])
            self.assertTrue(result['identity']['parallel'] == (phase == 'normal'))

    def test_selected_phase_rejects_other_source_and_rechecks_policy_before_success(self):
        profile = self.profile('normal')
        with self.context(), patch.dict(os.environ, {'GITHUB_SHA': 'b' * 40}), \
                patch.object(runner, 'reviewed_build_profile', return_value=profile), \
                self.assertRaisesRegex(ValueError, 'actual current-CI source'):
            runner.run_phase('normal', self.root / 'wrong-head', '/owned/policy', 'f' * 64)
        self.assertFalse(self.calls)
        with self.context(), patch.dict(os.environ, {'GITHUB_SHA': self.head}), \
                patch.object(runner, 'reviewed_build_profile', side_effect=[profile, ValueError('policy drift')]), \
                self.assertRaisesRegex(ValueError, 'policy drift'):
            runner.run_phase('normal', self.root / 'policy-drift', '/owned/policy', 'f' * 64)

    def test_profile_loader_requires_real_parent_and_immutable_exact_policy_bytes(self):
        import native_runner
        path = self.root / 'profile.json'
        policy = dict(approved_head=self.head)
        path.write_text(json.dumps(policy))
        path.chmod(0o400)
        checksum = runner.digest(path)
        environment = dict(GITHUB_JOB='native_phase', GITHUB_SHA=self.head,
                           ELITE_NATIVE_APPROVED_HEAD=self.head, ELITE_NATIVE_POLICY=str(path))
        profile = dict(build_profile='jobs1-nonbatch-v1', admission=self.profile('normal')['admission'])
        with patch.object(native_runner, 'read_local_components_binding') as binding, \
                patch.object(native_runner, 'phase_profile', return_value=profile):
            actual = runner.reviewed_build_profile(path, checksum, 'normal', environment)
            self.assertEqual(actual['admission'], profile['admission'])
            binding.assert_called_once_with(policy)
            for name in environment:
                with self.subTest(control=name), self.assertRaises(ValueError):
                    runner.reviewed_build_profile(path, checksum, 'normal', {**environment, name: 'wrong'})
            with self.assertRaises(ValueError):
                runner.reviewed_build_profile(path, 'e' * 64, 'normal', environment)
            path.chmod(0o600)
            with self.assertRaises(ValueError):
                runner.reviewed_build_profile(path, checksum, 'normal', environment)
        self.assertIsNone(runner.reviewed_build_profile(None, None, 'normal', {}))
        with self.assertRaises(ValueError):
            runner.reviewed_build_profile(None, checksum, 'normal', {})
    def test_selected_leak_command_uses_the_same_physical_image_as_its_identity(self):
        self.fail_leaks = False
        alias = self.root / 'bin-alias'
        alias.symlink_to(self.bins, target_is_directory=True)
        def output(command, *args):
            return str(alias) if '--show-bin-path' in command else self.output(command, *args)
        with self.context(), patch.dict(os.environ, {'GITHUB_SHA': self.head}), \
                patch.object(runner, 'reviewed_build_profile', return_value=self.profile('leaks')), \
                patch.object(runner, 'output', side_effect=output):
            runner.run_phase('leaks', self.root / 'physical-leaks', '/owned/policy', 'f' * 64)
        result = json.loads(next((self.root / 'physical-leaks').glob('phases/*/*/result.json')).read_text())
        self.assertEqual(result['identity']['phase_image'], str(self.bins / 'L337'))
        self.assertEqual(result['command'], ['/usr/bin/leaks', '--atExit', '--', str(self.bins / 'L337'), '--diagnostics'])


if __name__ == '__main__':
    unittest.main()


class NormalLeaksOnlyCITests(unittest.TestCase):
    setUp = QualityPhaseTests.setUp
    profile = OwnedPhaseBuildTests.profile
    def test_hosted_profiles_require_no_local_sanitizer_proof(self):
        import native_runner
        path = self.root / 'normal-leaks-policy.json'
        policy = dict(approved_head=self.head, recoverable_activation={}, recoverable_shards={
            'phase_profiles': {phase: dict(build_profile='jobs1-nonbatch-v1',
                                           admission=self.profile(phase)['admission'])
                               for phase in ('normal', 'leaks')}})
        def save():
            if path.exists():
                path.chmod(0o600)
            path.write_text(json.dumps(policy)); path.chmod(0o400)
            return dict(GITHUB_ACTIONS='true', GITHUB_JOB='native_checks', GITHUB_SHA=self.head,
                        ELITE_NATIVE_APPROVED_HEAD=self.head, ELITE_NATIVE_POLICY=str(path),
                        ELITE_RECOVERABLE_POLICY_SHA256=native_runner.policy_digest(policy))
        environment = save()
        with patch.object(native_runner, 'read_local_components_binding', side_effect=AssertionError('must not read sanitizer proof')):
            for phase in ('normal', 'leaks'):
                actual = runner.reviewed_build_profile(None, None, phase, environment)
                self.assertEqual(actual['admission'], self.profile(phase)['admission'])
            for fault in ('missing', 'empty', 'one-phase', 'malformed'):
                original = policy['recoverable_shards'].pop('phase_profiles', None)
                if fault == 'empty': policy['recoverable_shards']['phase_profiles'] = {}
                if fault == 'one-phase': policy['recoverable_shards']['phase_profiles'] = {'normal': original['normal']}
                if fault == 'malformed': policy['recoverable_shards']['phase_profiles'] = {'normal': {}, 'leaks': {}}
                environment = save()
                with self.subTest(fault=fault), self.assertRaises(ValueError):
                    runner.reviewed_build_profile(None, None, 'normal', environment)
                policy['recoverable_shards']['phase_profiles'] = original

    def test_hosted_phase_wraps_the_whole_helper_and_rejects_forged_parent(self):
        from types import SimpleNamespace
        import native_runner
        import recoverable_shards
        source = str(Path(runner.__file__).resolve())
        row = dict(start='fixed parent start', command=runner.sys.executable + ' ' + source + ' normal')
        authority = SimpleNamespace(snapshot=lambda: {os.getpid(): row}, root=self.root,
                                    admission=lambda **values: self.assertEqual(values, {'phase': 'normal'}))
        policy = self.root / 'policy.json'; policy.write_text('{}')
        environment = dict(GITHUB_ACTIONS='true', GITHUB_JOB='native_checks', ELITE_NATIVE_POLICY=str(policy))
        with patch.dict(os.environ, environment, clear=True), patch.object(runner, 'ROOT', self.root), \
                patch.object(runner, 'reviewed_build_profile'), \
                patch.object(recoverable_shards, 'NativeAuthority', return_value=authority), \
                patch.object(recoverable_shards, 'NativeMonitor', return_value=object()) as monitor, \
                patch.object(recoverable_shards, 'execute_process', return_value=0) as execute:
            runner.run_hosted_phase('normal')
            command = execute.call_args.args[0]
            self.assertEqual(command[:3], [runner.sys.executable, source, 'normal'])
            self.assertEqual(monitor.call_args.kwargs, {'phase': 'normal'})
            self.assertFalse(execute.call_args.kwargs['isolate_environment'])
            args = SimpleNamespace(phase='normal', monitor_parent=os.getpid(),
                                   monitor_parent_start=native_runner.custody_digest(row['start']),
                                   monitor_parent_command=native_runner.custody_digest(row['command']),
                                   profile_policy=policy, profile_policy_sha256=runner.digest(policy))
            with patch.object(runner.os, 'getppid', return_value=os.getpid()):
                runner.require_monitor_parent(args, authority)
                for field, changed in [('phase', 'leaks'), ('monitor_parent_start', 'changed'),
                                       ('monitor_parent_command', 'changed')]:
                    original = getattr(args, field); setattr(args, field, changed)
                    with self.subTest(field=field), self.assertRaises(ValueError):
                        runner.require_monitor_parent(args, authority)
                    setattr(args, field, original)
            with self.assertRaises(ValueError):
                runner.require_monitor_parent(args, authority)
            execute.return_value = 1
            with self.assertRaises(subprocess.CalledProcessError):
                runner.run_hosted_phase('normal')

    def test_framework_python_image_matches_only_its_own_runtime_prefix(self):
        prefix = self.root / 'runtime'
        launcher = prefix / 'bin/python3.12'
        image = prefix / 'Resources/Python.app/Contents/MacOS/Python'
        for file in (launcher, image):
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(b'fake interpreter image')
        with patch.object(runner.sys, 'executable', str(launcher)), \
                patch.object(runner.sys, 'base_prefix', str(prefix)), \
                patch.object(runner.sys, 'platform', 'darwin'), \
                patch.object(runner.sysconfig, 'get_config_var', return_value='Python'):
            self.assertEqual(runner.controller_interpreters(), {launcher, image})
            with patch.object(runner.sys, 'base_prefix', str(self.root / 'other-runtime')):
                self.assertEqual(runner.controller_interpreters(), {launcher})
            image.unlink()
            image.symlink_to(launcher)
            self.assertEqual(runner.controller_interpreters(), {launcher})
