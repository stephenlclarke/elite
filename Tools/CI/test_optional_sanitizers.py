"""Exercise the public Make targets without launching Swift or a sanitizer."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
THREAD = ['test', '--scratch-path', '.build/tsan', '--sanitize=thread']
ADDRESS = ['test', '--scratch-path', '.build/asan', '--sanitize=address', '--no-parallel']


class OptionalSanitizerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.log = self.directory / 'calls.jsonl'
        swift = self.directory / 'swift'
        swift.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['SANITIZER_TEST_LOG'], 'a') as stream:
    stream.write(json.dumps({'args': sys.argv[1:], 'asan': os.environ.get('ASAN_OPTIONS')}) + '\\n')
sys.exit(int(os.environ.get('SANITIZER_TEST_EXIT', '0')))
''')
        swift.chmod(0o700)
        self.environment = {key: value for key, value in os.environ.items()
                            if key not in ('MAKEFLAGS', 'MFLAGS', 'MAKEOVERRIDES', 'ELITE_SANITIZERS', 'ASAN_OPTIONS')}
        self.environment.update(PATH=str(self.directory) + os.pathsep + os.environ['PATH'],
                                SANITIZER_TEST_LOG=str(self.log))

    def make(self, *args):
        return subprocess.run(['make', '--no-print-directory', *args], cwd=ROOT,
                              env=self.environment, text=True, capture_output=True, timeout=15)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_thread_runs_original_whole_suite_without_controller(self):
        result = self.make('threads')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [{'args': THREAD, 'asan': None}])
        self.assertNotIn('python3', result.stdout)

    def test_address_keeps_original_serial_and_leak_options(self):
        self.environment['ASAN_OPTIONS'] = 'external-options'
        result = self.make('address')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [{'args': ADDRESS, 'asan': 'detect_leaks=0'}])
        self.assertNotIn('python3', result.stdout)

    def test_combined_target_stays_sequential_under_parallel_make(self):
        result = self.make('-j4', 'sanitizers')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [{'args': THREAD, 'asan': None},
                                       {'args': ADDRESS, 'asan': 'detect_leaks=0'}])

    def test_combined_target_stops_and_returns_failure(self):
        self.environment['SANITIZER_TEST_EXIT'] = '17'
        result = self.make('sanitizers')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [{'args': THREAD, 'asan': None}])

    def test_full_thread_alias_runs_same_command(self):
        result = self.make('threads-full')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [{'args': THREAD, 'asan': None}])

    def test_default_ci_keeps_required_checks_and_sanitizers_off(self):
        for setting in ((), ('ELITE_SANITIZERS=0',)):
            with self.subTest(setting=setting):
                result = self.make('-n', 'ci', *setting)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn('--sanitize=', result.stdout)
                self.assertIn('quality_phase_checkpoints.py normal', result.stdout)
                self.assertIn('quality_phase_checkpoints.py leaks', result.stdout)
                self.assertIn('script_instance_equality.py', result.stdout)
        self.assertFalse(self.log.exists())

    def test_opt_in_ci_adds_both_after_normal_checks(self):
        result = self.make('-n', 'ci', 'ELITE_SANITIZERS=1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('--sanitize=thread'), 1)
        self.assertEqual(result.stdout.count('--sanitize=address'), 1)
        self.assertLess(result.stdout.index('quality_phase_checkpoints.py leaks'),
                        result.stdout.index('--sanitize=thread'))
        self.assertLess(result.stdout.index('--sanitize=thread'), result.stdout.index('--sanitize=address'))
        self.assertFalse(self.log.exists())


if __name__ == '__main__':
    unittest.main()
