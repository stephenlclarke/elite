"""Checkpoint acceptance must reject partial or changed sanitizer evidence."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

from sanitizer_checkpoints import (atomic_json, digest, inspect_xml, inventory,
                                   owned_directory, partition, successful_attempt)


class SanitizerCheckpointTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.methods = ['EliteCoreTests.First/plain()', 'EliteCoreTests.First/rows(value:)']
        self.identity = {'mode': 'address', 'image_sha256': 'image', 'inputs': {'source': 'hash'}}

    def xml(self, methods=None, child=None):
        root = ET.Element('testsuites')
        suite = ET.SubElement(root, 'testsuite', tests=str(len(methods or self.methods)),
                              failures='0', errors='0', skipped='0')
        for method in self.methods if methods is None else methods:
            name, case = method.split('/', 1)
            node = ET.SubElement(suite, 'testcase', classname=name, name=case, time='1.0')
            if child:
                ET.SubElement(node, child)
        path = self.root / 'tests.xml'
        ET.ElementTree(root).write(path)
        return path

    def receipt(self):
        self.xml()
        (self.root / 'test.log').write_text('Complete original log\n')
        result = {'identity': self.identity, 'methods': self.methods, 'exit_code': 0,
                  'status': 'passed', 'tested_head': 'a' * 40, 'report': 'tests.xml',
                  'outputs': {name: digest(self.root / name) for name in ('test.log', 'tests.xml')}}
        atomic_json(self.root / 'result.json', result)
        return result

    def test_discovery_retains_parameterized_method_and_rejects_empty_duplicates(self):
        text = 'Building...\n' + '\n'.join(self.methods)
        self.assertEqual(inventory(text), self.methods)
        for invalid in ['', text + '\n' + self.methods[0]]:
            with self.assertRaises(ValueError):
                inventory(invalid)

    def test_top_level_nested_and_source_qualified_ids_are_never_omitted(self):
        import re
        from sanitizer_checkpoints import batch_command, xml_identity
        methods = [
            'EliteCoreTests.topPlain()',
            'EliteCoreTests.courierEveryDifficultyAndVariantUsesRuntimeTravelAndDurableContact(row:)/Courier.swift:12:3',
            'EliteCoreTests.Outer/Inner/nested(row:)/Nested.swift:9:4',
            'EliteCoreTests.Outer/plain()',
        ]
        expected_xml = [
            ('EliteCoreTests', 'topPlain()'),
            ('EliteCoreTests', 'courierEveryDifficultyAndVariantUsesRuntimeTravelAndDurableContact(row:)'),
            ('EliteCoreTests.Outer.Inner', 'nested(row:)'),
            ('EliteCoreTests.Outer', 'plain()'),
        ]
        self.assertEqual([xml_identity(method) for method in methods], expected_xml)
        self.assertEqual(inventory('Building...\n' + '\n'.join(methods)), sorted(methods))
        batches = partition(methods, 'address', target=2)
        self.assertEqual(sorted(sum(batches, [])), sorted(methods))
        nested_batch = next(batch for batch in batches if methods[2] in batch)
        self.assertIn(methods[3], nested_batch)
        for batch in batches:
            command = batch_command('/swift', [], 'address', self.root, batch)
            pattern = command[command.index('--filter') + 1]
            self.assertEqual(sorted(method for method in methods if re.search(pattern, method)), sorted(batch))
        root = ET.Element('testsuites')
        suite = ET.SubElement(root, 'testsuite', tests='4')
        for classname, name in expected_xml:
            ET.SubElement(suite, 'testcase', classname=classname, name=name, time='1')
        path = self.root / 'all.xml'
        ET.ElementTree(root).write(path)
        self.assertEqual(inspect_xml(path, methods), methods)
        suite.remove(list(suite)[0])
        suite.set('tests', '3')
        ET.ElementTree(root).write(path)
        with self.assertRaises(ValueError):
            inspect_xml(path, methods)
        duplicate_xml_id = methods[0] + '/Other.swift:1:1'
        with self.assertRaises(ValueError):
            inventory('\n'.join([*methods, duplicate_xml_id]))

    def test_asan_partition_keeps_whole_suites_and_exact_disjoint_union(self):
        methods = [f'EliteCoreTests.{suite}/method{index}()'
                   for suite, count in [('A', 2), ('B', 4), ('C', 1)] for index in range(count)]
        batches = partition(methods, 'address', target=3)
        self.assertEqual([len(batch) for batch in batches], [2, 4, 1])
        self.assertEqual(sorted(sum(batches, [])), sorted(methods))
        self.assertEqual(len(batches[1]), 4)  # An oversized suite is never split.

    def test_commands_preserve_full_tsan_concurrency_and_whole_suite_asan_selection(self):
        from sanitizer_checkpoints import batch_command
        thread = batch_command('/swift', ['--sanitize=thread'], 'thread', self.root, self.methods)
        self.assertNotIn('--filter', thread)
        self.assertNotIn('--no-parallel', thread)
        address = batch_command('/swift', ['--sanitize=address'], 'address', self.root, self.methods)
        self.assertIn('--no-parallel', address)
        pattern = address[address.index('--filter') + 1]
        self.assertTrue(__import__('re').search(pattern, self.methods[1]))
        self.assertFalse(__import__('re').search(pattern, 'EliteCoreTests.FirstOther/plain()'))

    def test_tsan_is_one_full_concurrent_group_even_above_target(self):
        self.assertEqual(partition(self.methods, 'thread', target=1), [self.methods])

    def test_partition_rejects_empty_duplicates_unknown_mode_and_invalid_target(self):
        for methods, mode, target in [([], 'address', 10), (self.methods * 2, 'address', 10),
                                      (self.methods, 'other', 10), (self.methods, 'thread', 0)]:
            with self.subTest(mode=mode, target=target), self.assertRaises(ValueError):
                partition(methods, mode, target)

    def test_xml_requires_exact_complete_unique_method_inventory(self):
        self.assertEqual(inspect_xml(self.xml(), self.methods), self.methods)
        for methods in [self.methods[:1], self.methods * 2,
                        self.methods + ['EliteCoreTests.Foreign/other()']]:
            with self.subTest(methods=methods), self.assertRaises(ValueError):
                inspect_xml(self.xml(methods), self.methods)
        (self.root / 'tests.xml').write_text('<testsuites>')
        with self.assertRaises(ET.ParseError):
            inspect_xml(self.root / 'tests.xml', self.methods)

    def test_xml_failure_error_skip_and_declared_failures_cannot_be_cached(self):
        for child in ['failure', 'error', 'skipped']:
            with self.subTest(child=child), self.assertRaises(ValueError):
                inspect_xml(self.xml(child=child), self.methods)
        path = self.xml()
        path.write_text(path.read_text().replace('failures="0"', 'failures="1"'))
        with self.assertRaises(ValueError):
            inspect_xml(path, self.methods)

    def test_declared_counts_and_incomplete_durations_cannot_qualify(self):
        path = self.xml()
        path.write_text(path.read_text().replace('tests="2"', 'tests="0"'))
        with self.assertRaises(ValueError):
            inspect_xml(path, self.methods)
        path = self.xml()
        path.write_text(path.read_text().replace('time="1.0"', 'time="nan"'))
        with self.assertRaises(ValueError):
            inspect_xml(path, self.methods)

    def test_exact_success_can_be_reused(self):
        expected = self.receipt()
        self.assertEqual(successful_attempt(self.root, self.identity, self.methods), expected)

    def test_source_image_mode_flags_or_selection_change_invalidates_reuse(self):
        self.receipt()
        for identity in [{**self.identity, 'mode': 'thread'},
                         {**self.identity, 'image_sha256': 'changed'},
                         {**self.identity, 'inputs': {'source': 'changed'}},
                         {**self.identity, 'flags': ['changed']}]:
            with self.subTest(identity=identity):
                self.assertIsNone(successful_attempt(self.root, identity, self.methods))
        self.assertIsNone(successful_attempt(self.root, self.identity, self.methods[:1]))

    def test_failed_incomplete_or_tampered_attempt_never_becomes_success(self):
        result = self.receipt()
        for key, value in [('exit_code', 1), ('status', 'failed'), ('tested_head', 'branch')]:
            changed = {**result, key: value}
            (self.root / 'result.json').write_text(json.dumps(changed))
            self.assertIsNone(successful_attempt(self.root, self.identity, self.methods))
        (self.root / 'result.json').write_text(json.dumps(result))
        (self.root / 'test.log').write_text('Different bytes')
        self.assertIsNone(successful_attempt(self.root, self.identity, self.methods))
        (self.root / 'result.json').unlink()
        self.assertIsNone(successful_attempt(self.root, self.identity, self.methods))

    def test_sanitizer_error_cannot_be_hidden_by_success_xml_or_exit_zero(self):
        result = self.receipt()
        (self.root / 'test.log').write_text('ERROR: AddressSanitizer: heap-buffer-overflow')
        result['outputs']['test.log'] = digest(self.root / 'test.log')
        (self.root / 'result.json').write_text(json.dumps(result))
        self.assertIsNone(successful_attempt(self.root, self.identity, self.methods))

    def test_links_or_publicly_writable_checkpoint_evidence_are_refused(self):
        self.receipt()
        link = self.root / 'link'
        link.symlink_to(self.root, target_is_directory=True)
        self.assertIsNone(successful_attempt(link, self.identity, self.methods))
        with self.assertRaises(ValueError):
            owned_directory(link / 'child')
        result = self.root / 'result.json'
        result.chmod(0o666)
        self.assertIsNone(successful_attempt(self.root, self.identity, self.methods))
        result.unlink()
        result.symlink_to(self.root / 'test.log')
        self.assertIsNone(successful_attempt(self.root, self.identity, self.methods))

    def test_atomic_receipt_is_complete_and_cannot_overwrite_an_interrupted_temporary(self):
        path = self.root / 'receipt.json'
        atomic_json(path, {'complete': True})
        self.assertEqual(json.loads(path.read_text()), {'complete': True})
        path.with_name('receipt.json.tmp').write_text('interrupted')
        with self.assertRaises(FileExistsError):
            atomic_json(path, {'complete': False})
        self.assertEqual(json.loads(path.read_text()), {'complete': True})


class SanitizerExecutionBoundaryTests(unittest.TestCase):
    def test_all_swift_queries_inherit_executor_lock_and_own_session(self):
        from sanitizer_checkpoints import output
        from types import SimpleNamespace
        lock = SimpleNamespace(fileno=lambda: 42)
        commands = [
            ['/swift', 'test', '--scratch-path', '.build/asan', 'list', '--skip-build'],
            ['/swift', 'build', '--show-bin-path'],
            ['/swift', '--version'],
        ]
        with patch('sanitizer_checkpoints.subprocess.check_output', return_value='ok') as execute:
            for command in commands:
                self.assertEqual(output(command, Path('/repo'), {}, lock), 'ok')
                self.assertEqual(execute.call_args.kwargs['pass_fds'], (42,))
                self.assertTrue(execute.call_args.kwargs['start_new_session'])

    def test_disconnected_existing_helper_blocks_replacement(self):
        from sanitizer_checkpoints import ensure_no_live_tests
        row = '42 /toolchain/swiftpm-testing-helper --test-bundle-path /owned/EliteCoreTests.xctest/Contents/MacOS/EliteCoreTests'
        with patch('sanitizer_checkpoints.subprocess.check_output', return_value=row):
            with self.assertRaisesRegex(ValueError, 'still active'):
                ensure_no_live_tests()
        with patch('sanitizer_checkpoints.subprocess.check_output', return_value='42 unrelated-app'):
            ensure_no_live_tests()

    def test_successful_batch_survives_later_failure_and_docs_only_head_change(self):
        import subprocess
        import sanitizer_checkpoints as runner
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            image = root / 'bin/EliteCoreTests.xctest/Contents/MacOS/EliteCoreTests'
            image.parent.mkdir(parents=True)
            image.write_bytes(b'fixed instrumented image')
            methods = ['EliteCoreTests.A/rows(value:)', 'EliteCoreTests.B/plain()']
            head = ['a' * 40]
            fail_second = [True]
            executions = []

            def fake_output(command, *_):
                if command[:2] == ['git', 'rev-parse']:
                    return head[0]
                if command[:2] == ['git', 'status']:
                    return ''
                if 'list' in command:
                    return '\n'.join(methods)
                if '--show-bin-path' in command:
                    return str(root / 'bin')
                return 'fixed toolchain identity'

            def fake_run(command, **options):
                self.assertTrue(options['pass_fds'])
                self.assertTrue(options['start_new_session'])
                if '--filter' not in command:
                    return subprocess.CompletedProcess(command, 0)
                self.assertIn('--no-parallel', command)
                self.assertEqual(options['env']['ASAN_OPTIONS'], 'detect_leaks=0')
                selected = [method for method in methods if __import__('re').search(command[-1], method)]
                executions.append(selected)
                requested = Path(command[command.index('--xunit-output') + 1])
                actual = requested.with_name('tests-swift-testing.xml')
                report = ET.Element('testsuites')
                suite = ET.SubElement(report, 'testsuite', tests=str(len(selected)))
                for method in selected:
                    classname, name = method.split('/')
                    ET.SubElement(suite, 'testcase', classname=classname, name=name, time='1')
                ET.ElementTree(report).write(actual)
                options['stdout'].write(b'Original batch output\n')
                if fail_second[0] and selected == methods[1:]:
                    return subprocess.CompletedProcess(command, 1)
                return subprocess.CompletedProcess(command, 0)

            with (patch.object(runner, 'ROOT', root),
                  patch.object(runner, 'output', side_effect=fake_output),
                  patch.object(runner, 'executable_inputs', return_value={'Sources/game.swift': 'fixed'}),
                  patch.object(runner, 'ensure_no_live_tests'),
                  patch.object(runner.shutil, 'which', return_value='/toolchain/swift'),
                  patch.object(runner.subprocess, 'run', side_effect=fake_run)):
                with self.assertRaisesRegex(ValueError, 'batch failed'):
                    runner.run_mode('address', root / 'cache', target=1)
                self.assertEqual(executions, [methods[:1], methods[1:]])
                fail_second[0] = False
                head[0] = 'b' * 40  # Same executable inputs, a later documentation commit.
                runner.run_mode('address', root / 'cache', target=1)
                self.assertEqual(executions, [methods[:1], methods[1:], methods[1:]])
                summaries = list((root / 'reports').glob('sanitizers/address/*/summary.json'))
                self.assertEqual(len(summaries), 1)
                summary = json.loads(summaries[0].read_text())
                self.assertEqual(summary['current_head'], 'b' * 40)
                self.assertEqual([batch['reused'] for batch in summary['batches']], [True, False])
                self.assertEqual(summary['batches'][0]['tested_head'], 'a' * 40)
                self.assertEqual(summary['batches'][1]['tested_head'], 'b' * 40)
                self.assertEqual(summary['complete_inventory'], methods)
                image.write_bytes(b'changed executable image')
                runner.run_mode('address', root / 'cache', target=1)
                self.assertEqual(executions[-2:], [methods[:1], methods[1:]])
                self.assertEqual(len(executions), 5)
                self.assertEqual(len([path for path in (root / 'cache').iterdir() if path.is_dir()]), 2)


if __name__ == '__main__':
    unittest.main()
