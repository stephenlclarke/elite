"""Fake normal evidence and real Git: no compiler or native process is launched."""
from copy import deepcopy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import m01_normal_attestation as attestor
import quality_phase_checkpoints as phases
from sanitizer_checkpoints import digest, runtime_identity


class M01NormalAttestationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name).resolve()
        self.root = self.home / 'repo'
        self.root.mkdir()
        self.tool = 'Tools/CI/test_quality_phase_checkpoints.py'
        for name, content in {self.tool: 'old fake fixture', 'Sources/fake.swift': 'unchanged source'}.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        self.git('init', '-q')
        self.git('add', '.')
        self.commit('test: baseline')
        self.old = self.git('rev-parse', 'HEAD').strip()
        old_hash = digest(self.root / self.tool)
        (self.root / self.tool).write_text('new fake fixture')
        self.git('add', '.')
        self.commit('test: updated fixture')
        self.head = self.git('rev-parse', 'HEAD').strip()
        self.deltas = {self.tool: {'old_sha256': old_hash, 'new_sha256': digest(self.root / self.tool)}}
        authorization = self.home / 'Library/EliteNativeAuthorization'
        self.old_policy_path = authorization / self.old / 'policy.json'
        self.new_policy_path = authorization / self.head / 'policy.json'
        policy = {'approved_head': self.old, 'guard_sha256': 'unchanged guard',
                  'runner_root': str(self.home / 'runner'), 'swift': 'same compiler', 'sdk': 'same SDK'}
        self.old_policy = policy
        self.new_policy = {**policy, 'approved_head': self.head}
        self.write_trust(self.old_policy_path, self.old_policy)
        self.write_trust(self.new_policy_path, self.new_policy)
        self.environment = {'PATH': '/fixed', 'ELITE_NATIVE_APPROVED_HEAD': self.head,
                            'ELITE_NATIVE_POLICY': str(self.new_policy_path)}
        old_environment = {**self.environment, 'ELITE_NATIVE_APPROVED_HEAD': self.old,
                           'ELITE_NATIVE_POLICY': str(self.old_policy_path)}
        self.old_identity = {'schema': 1, 'phase': 'normal',
                             'inputs': {self.tool: old_hash, 'Sources/fake.swift': 'fixed',
                                        '.build/checkouts/dependency.swift': 'fixed dependency'},
                             'environment': runtime_identity(old_environment),
                             'inventory': ['EliteCoreTests.Fixture/pass()'],
                             'opt_in_policy': {'expected_skips': []}, 'image_sha256': 'same image',
                             'image_uuid': 'same UUID', 'sdk': 'same SDK', 'swift': 'same compiler'}
        self.current = deepcopy(self.old_identity)
        self.current['inputs'][self.tool] = self.deltas[self.tool]['new_sha256']
        self.current['environment'] = runtime_identity(self.environment)
        self.binding = {'schema': 1, 'scope': 'M01-generated-profile-only',
                        'approved_head': self.head, 'old_approved_head': self.old,
                        'approved_tree': self.git('rev-parse', 'HEAD^{tree}').strip(), 'deltas': self.deltas}
        self.binding_path = self.new_policy_path.with_name('m01-normal-attestation.json')
        self.write_trust(self.binding_path, self.binding)
        self.cache = self.home / 'cache'
        self.attempt = self.cache / 'phases' / attestor.OLD_KEY / attestor.OLD_ATTEMPT
        self.attempt.mkdir(parents=True, mode=0o700)
        files = {'phase.log': 'Complete fake phase', 'coverage.lcov': 'fake LCOV',
                 'default.profdata': 'fake profile',
                 'coverage.xml': '<coverage><file path="Sources/fake.swift">'
                                 '<lineToCover lineNumber="1" covered="true"/></file></coverage>',
                 'tests-swift-testing.xml': '<testsuites><testsuite tests="1" failures="0" errors="0" skipped="0">'
                                            '<testcase classname="EliteCoreTests.Fixture" name="pass()" time="1"/>'
                                            '</testsuite></testsuites>'}
        for name, value in files.items():
            (self.attempt / name).write_text(value)
            (self.attempt / name).chmod(0o400)
        self.result = {'identity': self.old_identity, 'tested_head': self.old, 'status': 'passed',
                       'exit_code': 0, 'test_wall_seconds': 1,
                       'validation': {'covered_lines': 1, 'total_lines': 1, 'percent': 100.0},
                       'outputs': {name: digest(self.attempt / name) for name in files}}
        self.write_trust(self.attempt / 'result.json', self.result)
        self.original_result_hash = digest(self.attempt / 'result.json')
        self.attempt.chmod(0o500)
        for name, value in {'OLD_APPROVED': self.old, 'OLD_TESTED': self.old,
                            'OLD_RESULT_SHA': self.original_result_hash,
                            'OLD_POLICY_SHA': digest(self.old_policy_path)}.items():
            patched = patch.object(attestor, name, value)
            patched.start()
            self.addCleanup(patched.stop)

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, text=True, stderr=subprocess.PIPE)

    def commit(self, message):
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                 '-c', 'commit.gpgsign=false', 'commit', '-qm', message)

    def write_trust(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            path.chmod(0o600)
        path.write_text(json.dumps(value))
        path.chmod(0o400)

    def qualify(self):
        with patch.object(Path, 'home', return_value=self.home), \
                patch('native_runner.validate', return_value=self.root) as trust:
            result = attestor.qualify(self.root, self.head, self.current, self.environment,
                                      self.cache, phases.successful_phase)
        trust.assert_called_once_with(self.new_policy, self.environment)
        return result

    def test_explicit_attestation_preserves_original_receipt_and_records_zero_new_execution(self):
        attempt, result, receipt = self.qualify()
        self.assertEqual(attempt, self.attempt)
        self.assertEqual(result, self.result)
        self.assertEqual(receipt['status'], 'attested-from-prior-execution')
        self.assertEqual((receipt['tested_head'], receipt['qualified_head']), (self.old, self.head))
        self.assertEqual(receipt['new_test_execution_seconds'], 0)
        self.assertEqual(receipt['original_identity'], self.old_identity)
        self.assertEqual(receipt['current_identity'], self.current)
        self.assertEqual(digest(self.attempt / 'result.json'), self.original_result_hash)
        self.assertIsNone(phases.successful_phase(self.attempt, self.current))

    def test_no_installed_binding_has_no_attestation(self):
        self.binding_path.unlink()
        self.assertIsNone(attestor.qualify(self.root, self.head, self.current, self.environment,
                                          self.cache, phases.successful_phase))

    def test_runtime_dependency_selection_image_toolchain_optins_and_environment_drift_fail_closed(self):
        cases = [({'inputs': {**self.current['inputs'], key: 'changed'}}, key)
                 for key in ('Sources/fake.swift', '.build/checkouts/dependency.swift')]
        cases += [({key: 'changed'}, key) for key in ('inventory', 'image_sha256', 'image_uuid', 'sdk',
                                                    'swift', 'opt_in_policy')]
        cases += [({'environment': {**self.current['environment'], 'ELITE_NEW_OPT_IN': 'changed'}}, 'environment')]
        original = self.current
        for change, label in cases:
            with self.subTest(field=label):
                self.current = {**original, **change}
                with self.assertRaises(ValueError):
                    self.qualify()
        self.current = original

    def test_unreviewed_tool_hash_or_manifest_delta_is_rejected(self):
        self.current['inputs'][self.tool] = 'unreviewed'
        with self.assertRaisesRegex(ValueError, 'hash-bound'):
            self.qualify()
        self.current['inputs'][self.tool] = self.deltas[self.tool]['new_sha256']
        self.binding['deltas'][self.tool]['new_sha256'] = 'unreviewed'
        self.write_trust(self.binding_path, self.binding)
        with self.assertRaisesRegex(ValueError, 'blob differs'):
            self.qualify()

    def test_source_commit_dirty_checkout_and_wrong_qualified_head_are_rejected(self):
        source = self.root / 'Sources/fake.swift'
        source.write_text('changed source')
        with self.assertRaisesRegex(ValueError, 'clean approved tree'):
            self.qualify()
        self.git('add', '.')
        self.commit('fix: unapproved source')
        self.head = self.git('rev-parse', 'HEAD').strip()
        with self.assertRaisesRegex(ValueError, 'clean approved tree'):
            self.qualify()

    def test_policy_semantics_and_authorization_environment_cannot_be_normalized(self):
        self.new_policy['guard_sha256'] = 'different guard'
        self.write_trust(self.new_policy_path, self.new_policy)
        with self.assertRaisesRegex(ValueError, 'semantics changed'):
            self.qualify()
        self.new_policy['guard_sha256'] = self.old_policy['guard_sha256']
        self.write_trust(self.new_policy_path, self.new_policy)
        self.current['environment']['ELITE_NATIVE_POLICY'] = 'unbound path'
        with self.assertRaisesRegex(ValueError, 'policy-bound'):
            self.qualify()

    def test_modified_receipt_outputs_or_policy_permissions_cannot_attest(self):
        output = self.attempt / 'coverage.xml'
        output.chmod(0o600)
        output.write_text('<coverage/>')
        output.chmod(0o400)
        with self.assertRaisesRegex(ValueError, 'outputs no longer qualify'):
            self.qualify()
        self.binding_path.chmod(0o600)
        with self.assertRaisesRegex(ValueError, 'immutable'):
            self.qualify()


if __name__ == '__main__':
    unittest.main()
