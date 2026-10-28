#!/usr/bin/env python3
"""Reuse only complete, identity-bound normal/coverage and leak phase outcomes."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET

from crash_artifacts import runtime_child_environment
from sanitizer_checkpoints import (ERRORS, atomic_json, copy_report, digest, ensure_no_live_tests,
                                   executable_inputs, inspect_xml, inventory, opt_in_policy,
                                   output, owned_directory, runtime_identity, selected_opt_in_skips)

ROOT = Path(__file__).resolve().parents[2]
NORMAL_OUTPUTS = {'phase.log', 'tests-swift-testing.xml', 'coverage.xml', 'coverage.lcov', 'default.profdata'}


def validate_coverage(path, inputs):
    root = ET.parse(path).getroot()
    lines = list(root.iter('lineToCover'))
    if root.tag != 'coverage' or not lines:
        raise ValueError('Coverage report must contain source lines')
    if any(file.attrib.get('path') not in inputs or not file.attrib['path'].startswith('Sources/')
           for file in root.iter('file')):
        raise ValueError('Coverage source is outside the bound source inventory')
    if any(line.attrib.get('covered') not in ('true', 'false') for line in lines):
        raise ValueError('Coverage line has an invalid outcome')
    covered = sum(line.attrib['covered'] == 'true' for line in lines)
    if covered / len(lines) < 0.8:
        raise ValueError('Swift coverage is below the existing 80 percent gate')
    return {'covered_lines': covered, 'total_lines': len(lines), 'percent': 100 * covered / len(lines)}


def validate_leaks(text):
    counts = re.findall(r'\b(\d+) leaks? for (\d+) total leaked bytes\b', text)
    if not counts or any(int(leaks) or int(size) for leaks, size in counts):
        raise ValueError('Leak report does not establish zero leaks')


def validate_outputs(attempt, identity):
    text = (attempt / 'phase.log').read_text(errors='replace')
    if any(marker in text for marker in ERRORS):
        raise ValueError('Runtime diagnostic in phase output')
    if identity['phase'] == 'normal':
        if (attempt / 'tests.xml').exists():
            extra = ET.parse(attempt / 'tests.xml').getroot()
            if (extra.tag not in ('testsuite', 'testsuites')
                    or any(list(extra.iter(tag)) for tag in ('testcase', 'failure', 'error', 'skipped', 'disabled'))
                    or any(int(node.attrib[key]) != 0 for node in extra.iter()
                           for key in ('tests', 'failures', 'errors', 'skipped', 'disabled') if key in node.attrib)):
                raise ValueError('Unaccounted XCTest outcomes outside discovered Swift Testing inventory')
        inspect_xml(attempt / 'tests-swift-testing.xml', identity['inventory'],
                    selected_opt_in_skips(identity, identity['inventory']))
        return validate_coverage(attempt / 'coverage.xml', identity['inputs'])
    validate_leaks(text)
    return {'zero_leaks': True}


def successful_phase(attempt, identity):
    """A failed, partial, tampered or differently configured attempt is never reusable."""
    try:
        if attempt.is_symlink() or attempt.stat().st_uid != os.getuid() or attempt.stat().st_mode & 0o022:
            return None
        receipt = attempt / 'result.json'
        if receipt.is_symlink() or receipt.stat().st_uid != os.getuid() or receipt.stat().st_mode & 0o022:
            return None
        result = json.loads(receipt.read_text())
        if (result['identity'] != identity or result['status'] != 'passed' or result['exit_code'] != 0
                or not re.fullmatch(r'[0-9a-f]{40}', result['tested_head'])):
            return None
        expected = phase_outputs(attempt, identity['phase'])
        if set(result['outputs']) != expected:
            return None
        if {file.name for file in attempt.glob('*.xml')} != {name for name in expected if name.endswith('.xml')}:
            return None
        for name, expected_hash in result['outputs'].items():
            file = attempt / name
            if (file.is_symlink() or not file.is_file() or file.stat().st_uid != os.getuid()
                    or file.stat().st_mode & 0o022 or digest(file) != expected_hash):
                return None
        if result['validation'] != validate_outputs(attempt, identity):
            return None
        return result
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError):
        return None


def execute(command, root, environment, lock, log):
    result = subprocess.run(command, cwd=root, env=environment, stdout=log, stderr=subprocess.STDOUT,
                            pass_fds=(lock.fileno(),), start_new_session=True)
    if result.returncode:
        raise subprocess.CalledProcessError(result.returncode, command)


def phase_outputs(attempt, phase):
    names = (NORMAL_OUTPUTS | ({'tests.xml'} if (attempt / 'tests.xml').exists() else set())
             if phase == 'normal' else {'phase.log'})
    return names | ({'build.log'} if (attempt / 'build.log').exists() else set())


def reviewed_build_profile(path, checksum, phase, environment):
    import native_runner
    if path is None and checksum is None:
        return None
    if path is None or not checksum or not re.fullmatch(r'[0-9a-f]{64}', checksum):
        raise ValueError('An owned phase policy and separate raw checksum are required')
    path = Path(path)
    native_runner.require_owned_activation_file(path)
    if (not path.is_absolute() or path != path.resolve() or path.stat().st_mode & 0o777 != 0o400
            or digest(path) != checksum):
        raise ValueError('Phase build policy ownership or bytes changed')
    policy = json.loads(path.read_text())
    native_runner.read_local_components_binding(policy)
    if (environment.get('GITHUB_JOB') != 'native_phase'
            or environment.get('GITHUB_SHA') != policy['approved_head']
            or environment.get('ELITE_NATIVE_APPROVED_HEAD') != policy['approved_head']
            or environment.get('ELITE_NATIVE_POLICY') != str(path)):
        raise ValueError('Phase build profile is outside its real current-CI parent authorization')
    profile = native_runner.phase_profile(policy, phase)
    return {'kind': 'owned-phase-build-v1', 'phase': phase, 'profile': profile['build_profile'],
            'policy_sha256': native_runner.policy_digest(policy), 'admission': profile['admission'],
            'flags': ['--jobs', '1', '-Xswiftc', '-disable-batch-mode']}


def run_phase(phase, cache, profile_policy=None, profile_sha256=None):
    root = ROOT
    build_profile = reviewed_build_profile(profile_policy, profile_sha256, phase, os.environ)
    owned_directory(cache)
    descriptor = os.open(cache / 'executor.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'a') as lock:
        if os.fstat(lock.fileno()).st_uid != os.getuid() or os.fstat(lock.fileno()).st_mode & 0o022:
            raise ValueError('Executor lock must be owned')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        ensure_no_live_tests()
        environment = runtime_child_environment(os.environ)
        swift = shutil.which('swift')
        if swift is None:
            raise ValueError('Swift toolchain is unavailable')
        head = output(['git', 'rev-parse', 'HEAD'], root, environment, lock)
        if build_profile is not None and head != os.environ['GITHUB_SHA']:
            raise ValueError('Phase profile requires the actual current-CI source')
        if output(['git', 'status', '--porcelain'], root, environment, lock):
            raise ValueError('Quality checkpoints require a clean committed checkout')
        report = root / 'reports/quality-phases' / phase / str(uuid.uuid4())
        report.mkdir(parents=True)
        flags = ['--enable-code-coverage'] if phase == 'normal' else []
        build_flags = build_profile['flags'] if build_profile is not None else []
        build_command = [swift, 'build', *(['--build-tests'] if phase == 'normal' else []), *flags, *build_flags]
        before = executable_inputs(root, '.build')
        started = time.monotonic()
        try:
            with (report / 'build.log').open('xb') as log:
                execute(build_command, root, environment, lock, log)
        except (OSError, subprocess.CalledProcessError) as error:
            atomic_json(report / 'phase-failure.json', {'status': 'failed', 'failure_kind': 'build',
                        'reason': str(error), 'exit_code': getattr(error, 'returncode', None),
                        'build_wall_seconds': time.monotonic() - started, 'test_wall_seconds': None})
            raise
        build_wall = time.monotonic() - started
        try:
            bins = Path(output([swift, 'build', *flags, *build_flags, '--show-bin-path'], root, environment, lock))
            if phase == 'normal':
                images = [file for file in bins.glob('*.xctest/Contents/MacOS/*') if file.is_file()]
                listing = output([swift, 'test', *flags, 'list', '--skip-build'], root, environment, lock)
                methods = inventory(listing)
            else:
                images, methods = [bins / 'Elite'], []
            if len(images) != 1 or not images[0].is_file():
                raise ValueError('Expected exactly one actual phase image')
            image = images[0].resolve() if build_profile is not None else images[0]
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            atomic_json(report / 'phase-failure.json', {'status': 'failed', 'failure_kind': 'discovery',
                        'reason': str(error), 'exit_code': getattr(error, 'returncode', None),
                        'build_wall_seconds': build_wall, 'test_wall_seconds': None})
            raise
        inputs = executable_inputs(root, '.build')
        if any(inputs.get(name) != value for name, value in before.items()):
            raise ValueError('Inputs changed during phase build')
        identity = {'schema': 1, 'phase': phase, 'inputs': inputs, 'inventory': methods,
                    'policy': 'normal-coverage-80-v1' if phase == 'normal' else 'leaks-at-exit-diagnostics-v1',
                    'flags': flags, 'parallel': phase == 'normal', 'environment': runtime_identity(environment),
                    'architecture': platform.machine(),
                    'os_version': {'release': os.uname().release, 'version': os.uname().version},
                    'swift_executable': swift, 'swift': output([swift, '--version'], root, environment, lock),
                    'sdk': output(['xcrun', '--show-sdk-version'], root, environment, lock),
                    'sdk_path': output(['xcrun', '--show-sdk-path'], root, environment, lock),
                    'image_sha256': digest(image),
                    'image_uuid': output(['xcrun', 'dwarfdump', '--uuid', str(image)], root, environment, lock),
                    'opt_in_policy': opt_in_policy(root, environment) if phase == 'normal' else {}}
        if build_profile is not None:
            identity['build_profile'] = {**build_profile, 'argv': build_command}
            identity['phase_image'] = str(image.resolve())
        key = digest_identity(identity)
        storage = cache / 'phases' / key
        owned_directory(storage)
        reused = next(((attempt, result) for attempt in sorted(storage.iterdir())
                       if attempt.is_dir() and (result := successful_phase(attempt, identity))), None)
        from m01_normal_attestation import qualify
        attested = qualify(root, head, identity, environment, cache, successful_phase) if phase == 'normal' and build_profile is None else None
        if attested:
            attempt, result, attestation = attested
        elif reused:
            attempt, result = reused
        else:
            attempt = storage / str(uuid.uuid4())
            owned_directory(attempt)
            if build_profile is not None:
                shutil.copyfile(report / 'build.log', attempt / 'build.log')
            command = ([swift, 'test', *flags, '--skip-build', '--xunit-output', str(attempt / 'tests.xml')]
                       if phase == 'normal' else ['/usr/bin/leaks', '--atExit', '--', str(image), '--diagnostics'])
            atomic_json(attempt / 'start.json', {'tested_head': head, 'identity': identity,
                                                'command': command, 'started_utc': time.time()})
            result = {'tested_head': head, 'identity': identity, 'command': command,
                      'status': 'failed', 'exit_code': None, 'native_exit_code': None, 'outputs': {}}
            started = time.monotonic()
            native_wall = None
            failure_kind = 'test-process' if phase == 'normal' else 'leak-process'
            try:
                with (attempt / 'phase.log').open('xb') as log:
                    native_started = time.monotonic()
                    try:
                        execute(command, root, environment, lock, log)
                        result['native_exit_code'] = 0
                    except subprocess.CalledProcessError as error:
                        result['native_exit_code'] = error.returncode
                        raise
                    finally:
                        native_wall = time.monotonic() - native_started
                    result['exit_code'] = 0
                    failure_kind = 'evidence-validation'
                    if phase == 'normal':
                        profile = bins / 'codecov/default.profdata'
                        shutil.copyfile(profile, attempt / 'default.profdata')
                        failure_kind = 'coverage-tool'
                        with (attempt / 'coverage.lcov').open('xb') as export:
                            execute(['xcrun', 'llvm-cov', 'export', '-format=lcov',
                                     '-instr-profile=' + str(profile), str(image), '--sources', 'Sources'],
                                    root, environment, lock, export)
                        execute(['python3', 'Tools/coverage/lcov-to-sonarqube-generic.py',
                                 str(attempt / 'coverage.lcov'), str(attempt / 'coverage.xml'),
                                 '--exclude', '*/Sources/CLua/*'], root, environment, lock, log)
                        execute(['python3', 'Tools/coverage/check-coverage.py', '--minimum', '80',
                                 '--coverage', str(attempt / 'coverage.xml')], root, environment, lock, log)
                if executable_inputs(root, '.build') != inputs or digest(image) != identity['image_sha256']:
                    raise ValueError('Inputs or executable image changed during phase')
                failure_kind = 'evidence-validation'
                result['validation'] = validate_outputs(attempt, identity)
                names = phase_outputs(attempt, phase)
                result.update(status='passed', outputs={name: digest(attempt / name) for name in sorted(names)})
            except (OSError, ValueError, ET.ParseError, subprocess.CalledProcessError) as error:
                if isinstance(error, subprocess.CalledProcessError):
                    result['exit_code'] = error.returncode
                    result['failed_command'] = error.cmd
                text = (attempt / 'phase.log').read_text(errors='replace') if (attempt / 'phase.log').exists() else ''
                if result['native_exit_code'] not in (None, 0) and (
                        result['native_exit_code'] < 0 or 'unexpected signal' in text or any(marker in text for marker in ERRORS)):
                    failure_kind = 'runtime-diagnostic-or-signal'
                result.update(reason=str(error), failure_kind=failure_kind)
            result['phase_wall_seconds'] = time.monotonic() - started
            result['test_wall_seconds'] = native_wall
            result['postprocess_wall_seconds'] = (result['phase_wall_seconds'] - native_wall
                                                   if native_wall is not None else None)
            atomic_json(attempt / 'result.json', result)
            for file in attempt.iterdir():
                file.chmod(0o400)
            attempt.chmod(0o500)
            if result['status'] != 'passed':
                copy_report(attempt, report / 'failed')
                raise ValueError('Quality phase failed; original attempt retained: ' + str(attempt))
        if (executable_inputs(root, '.build') != inputs or digest(image) != identity['image_sha256']
                or output(['git', 'rev-parse', 'HEAD'], root, environment, lock) != head
                or output(['git', 'status', '--porcelain'], root, environment, lock)):
            raise ValueError('Checkout changed before phase qualification')
        if build_profile is not None:
            reviewed_build_profile(profile_policy, profile_sha256, phase, os.environ)
        if attested:
            atomic_json(report / 'attestation.json', attestation)
        else:
            copy_report(attempt, report / 'completed')
        if phase == 'normal':
            for name in ('coverage.xml', 'coverage.lcov'):
                shutil.copyfile(attempt / name, root / name)
            print('Swift coverage: %.2f%%' % result['validation']['percent'], flush=True)
        else:
            shutil.copyfile(attempt / 'phase.log', root / 'reports/leaks.txt')
        atomic_json(report / 'summary.json', {'status': 'passed', 'current_head': head,
                    'tested_head': result['tested_head'], 'identity': identity, 'attempt': str(attempt),
                    'reused': bool(reused) and not bool(attested), 'attested': bool(attested),
                    'build_wall_seconds': build_wall,
                    'executed_test_wall_seconds': 0 if reused or attested else result['test_wall_seconds'],
                    'reused_original_test_wall_seconds': result['test_wall_seconds'] if reused or attested else 0,
                    'outputs': result['outputs'], 'validation': result['validation'],
                    'qualification': ('M01 normal attested from prior execution; see attestation.json. '
                                      if attested else '')
                    + 'This phase only; aggregate make ci requires every other gate.'})
        outcome = 'attested from prior execution' if attested else ('reused' if reused else 'executed')
        print(phase + ': complete phase ' + outcome, flush=True)


def digest_identity(identity):
    import hashlib
    return hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['normal', 'leaks'])
    parser.add_argument('--cache', type=Path, default=Path.home() / 'Library/EliteNativeCI/sanitizer-checkpoints')
    parser.add_argument('--profile-policy', type=Path)
    parser.add_argument('--profile-policy-sha256')
    args = parser.parse_args()
    run_phase(args.phase, args.cache, args.profile_policy, args.profile_policy_sha256)


if __name__ == '__main__':
    main()
