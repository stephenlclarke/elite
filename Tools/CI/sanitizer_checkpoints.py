#!/usr/bin/env python3
"""Resume complete sanitizer groups; full concurrent TSAN remains a separate policy."""
import argparse
from collections import Counter
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET

from crash_artifacts import runtime_child_environment

ROOT = Path(__file__).resolve().parents[2]
ERRORS = ('ERROR: AddressSanitizer:', 'WARNING: ThreadSanitizer:',
          'AddressSanitizer: CHECK failed', 'SUMMARY: AddressSanitizer:',
          'SUMMARY: ThreadSanitizer:')


def digest(path):
    """Hash large images and logs without loading them into memory."""
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def runtime_identity(environment):
    """Bind controls which can affect execution, including all authored test opt-ins."""
    names = {'PATH', 'HOME', 'TMPDIR', 'LANG', 'TZ', 'LLVM_PROFILE_FILE', 'DEVELOPER_DIR', 'SDKROOT', 'TOOLCHAINS',
             'SWIFT_EXEC', 'ASAN_OPTIONS', 'TSAN_OPTIONS', 'MallocStackLogging', 'MallocScribble'}
    names.update(key for key in environment if key.startswith(('ELITE_', 'SWIFT_', 'DYLD_', 'LC_')))
    return {key: hashlib.sha256(environment[key].encode()).hexdigest() if key in environment else None
            for key in sorted(names)}


def atomic_json(path, value):
    """Publish a complete receipt only after its data reaches disk."""
    temporary = path.with_name(path.name + '.tmp')
    with temporary.open('x') as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)


def owned_directory(path):
    """Refuse links and writable or foreign checkpoint directories."""
    if any(parent.is_symlink() for parent in (path, *path.parents)):
        raise ValueError('Checkpoint directory must not be a symbolic link')
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    info = path.stat()
    if not path.is_dir() or info.st_uid != os.getuid() or info.st_mode & 0o022:
        raise ValueError('Checkpoint directory must be owned and not publicly writable')


def identifier(raw):
    """Map Swift Testing's module/name components and optional source suffix to XML."""
    base = re.sub(r'/[^/]+:[1-9][0-9]*:[1-9][0-9]*$', '', raw)
    module, separator, remainder = base.partition('.')
    components = remainder.split('/')
    if (not separator or not re.fullmatch(r'[A-Za-z_]\w*', module)
            or not all(components) or any(character.isspace() for character in base)
            or (len(components) == 1 and not components[0].endswith(')'))):
        raise ValueError('Unsupported discovered test identifier: ' + raw)
    return module, components


def xml_identity(raw):
    module, components = identifier(raw)
    return '.'.join([module, *components[:-1]]), components[-1]


def group_key(raw):
    module, components = identifier(raw)
    # Nested suites stay with their outer suite. An unsuited function is one whole test.
    return (module, components[0])


def inventory(text):
    """Keep top-level, nested and parameterized IDs; never discard an unknown test row."""
    methods = []
    for line in text.splitlines():
        raw = line.strip()
        if re.match(r'^[A-Za-z_]\w*\.', raw) and ('(' in raw or '/' in raw):
            identifier(raw)
            methods.append(raw)
    if (not methods or len(set(methods)) != len(methods)
            or len({xml_identity(method) for method in methods}) != len(methods)):
        raise ValueError('Test discovery must be nonempty and unambiguous in XML')
    return sorted(methods)


def partition(methods, mode, target=100, shared_groups=(), full_concurrent=False):
    """Pack whole suites; audited shared-state participants remain in one process."""
    if not methods or len(set(methods)) != len(methods) or target < 1:
        raise ValueError('Invalid sanitizer selection')
    if full_concurrent and mode != 'thread':
        raise ValueError('Full concurrent policy requires thread mode')
    if mode == 'thread' and full_concurrent:
        return [sorted(methods)]
    if mode not in ('address', 'thread'):
        raise ValueError('Unknown sanitizer mode')
    suites = {}
    for method in sorted(methods):
        suites.setdefault(group_key(method), []).append(method)
    batches, pending = [], []
    reserved = set()
    for group in shared_groups:
        selected = set(group)
        if not selected or not selected <= set(methods) or reserved & selected:
            raise ValueError('Shared group is empty, overlapping or outside discovery')
        keys = {group_key(method) for method in selected}
        if selected != {method for method in methods if group_key(method) in keys}:
            raise ValueError('Shared group splits a suite')
        batches.append(sorted(selected))
        reserved.update(selected)
    for suite in suites.values():
        if suite[0] in reserved:
            continue
        if pending and len(pending) + len(suite) > target:
            batches.append(pending)
            pending = []
        pending.extend(suite)
        if len(pending) >= target:
            batches.append(pending)
            pending = []
    if pending:
        batches.append(pending)
    if Counter(method for batch in batches for method in batch) != Counter(methods):
        raise ValueError('Batch partition changed the full selection')
    return batches


def grouping_policy(root, methods, mode, target, full_concurrent=False):
    """Fail closed when the reviewed shared-state source or inventory changes."""
    if mode != 'thread' or full_concurrent:
        return {'policy': 'full-concurrent-v1' if full_concurrent else 'whole-suite-v1',
                'target': target, 'shared_groups': []}
    manifest = json.loads((root / 'Tools/CI/sanitizer_groups.json').read_text())
    if manifest['schema'] != 1:
        raise ValueError('Unknown shared-state grouping schema')
    by_name = {'/'.join(xml_identity(method)): method for method in methods}
    groups = []
    for entry in manifest['groups']:
        for name, expected in entry['sources'].items():
            path = root / name
            if path.is_symlink() or digest(path) != expected:
                raise ValueError('Shared-state source requires grouping review: ' + name)
        members = entry['members']
        if len(set(members)) != len(members) or any(name not in by_name for name in members):
            raise ValueError('Shared-state group no longer matches discovered inventory')
        groups.append([by_name[name] for name in members])
    # A new AppKit consumer must be audited instead of silently losing shared-process coverage.
    appkit = next(entry for entry in manifest['groups'] if entry['name'] == 'appkit-shared-process')
    consumers = {str(path.relative_to(root)) for path in (root / 'Tests/EliteCoreTests').glob('*.swift')
                 if '@Test' in path.read_text() and re.search(
                     r'import (?:AppKit|EliteMac)\b|PlanetRenderer\.|NSApplication\.shared|NSApp\b',
                     path.read_text())}
    if consumers != set(appkit['sources']):
        raise ValueError('AppKit participant source set requires grouping review')
    salvage = next(entry for entry in manifest['groups'] if entry['name'] == 'salvage-shared-release')
    consumers = {str(path.relative_to(root)) for path in (root / 'Tests/EliteCoreTests').glob('*.swift')
                 if re.search(r'NativeSalvageAdmissionTestFixture|NativeSalvageReleaseSnapshot', path.read_text())}
    if consumers != set(salvage['sources']):
        raise ValueError('Salvage shared fixture participant set requires grouping review')
    partition(methods, mode, target, groups)
    return {'policy': 'recoverable-thread-v1', 'target': target,
            'manifest': manifest, 'shared_groups': groups,
            'coverage': 'Internal concurrency and audited groups retained; arbitrary cross-group overlap differs.'}


GPU_OPT_IN = (
    'allPalettesMatchStableCPUReferenceIncludingWrappedLongitudeAndAlpha()',
    'identityChangesAndOutputReuseCannotMutatePreviouslyPublishedImages()',
    'nightEmissionAndMovingSunMatchCPUForEconomyGovernmentAndTechnology()',
    'productionRendererUsesPreparedGPUWithIndependentReferenceAndCache()',
    'invalidBoundsAndAnglesReturnCPUFallback()',
)
DIAGNOSTIC_METHOD = 'retained542SecondCycleContinuationDiagnostic()'
DIAGNOSTIC_REASON = 'Requires explicit diagnostic opt-in and the private retained run 542 directory'
LEGACY_VALIDATION_INPUTS = {
    'Tools/CI/sanitizer_checkpoints.py': 'fd0ca74766dcaf0ff198ecd2416957befd73d198dc209b9ca6f25a5715de1a5b',
    'Tools/CI/test_sanitizer_checkpoints.py': '2e5f1393c31672c3cf6f7802f5c3f4acfcf1798fa43cbc1b311644233e16de5d',
}


def opt_in_policy(root, environment):
    """Bind only six existing, source-declared opt-ins; never allow a general skip."""
    gpu_path = 'Tests/EliteCoreTests/PlanetGPUShaderTests.swift'
    diagnostic_path = 'Tests/EliteCoreTests/NativeMultiBatchRuntimeTests.swift'
    gpu = (root / gpu_path).read_text()
    diagnostic = (root / diagnostic_path).read_text()
    compact = lambda value: re.sub(r'\s+', '', value)
    gpu_guard = '@Suite(\n  .enabled(if: ProcessInfo.processInfo.environment["ELITE_PLANET_GPU_EXPERIMENT"] == "1"),\n  .serialized)\nstruct PlanetGPUShaderTests'
    diagnostic_guard = '@Test(\n    .enabled(\n      if: ProcessInfo.processInfo.environment["ELITE_NATIVE_WORK_CONTINUATION"] == "1"\n        && ProcessInfo.processInfo.environment["ELITE_NATIVE_WORK_CONTINUATION_SOURCE"]?.isEmpty\n          == false,\n      "Requires explicit diagnostic opt-in and the private retained run 542 directory")\n  )\n  func retained542SecondCycleContinuationDiagnostic()'
    names = set(re.findall(r'@MainActor\s+@Test\s+func\s+(\w+)\s*\(', gpu))
    if (compact(gpu_guard) not in compact(gpu) or names != {name[:-2] for name in GPU_OPT_IN}
            or compact(diagnostic_guard) not in compact(diagnostic)
            or DIAGNOSTIC_REASON not in diagnostic):
        raise ValueError('Source-declared opt-in guards changed; policy review required')
    source = environment.get('ELITE_NATIVE_WORK_CONTINUATION_SOURCE')
    controls = {
        'ELITE_PLANET_GPU_EXPERIMENT': environment.get('ELITE_PLANET_GPU_EXPERIMENT'),
        'ELITE_NATIVE_WORK_CONTINUATION': environment.get('ELITE_NATIVE_WORK_CONTINUATION'),
        'continuation_source_is_set': source is not None,
        'continuation_source_nonempty': bool(source),
        'continuation_source_sha256': hashlib.sha256(source.encode()).hexdigest() if source is not None else None,
    }
    skipped = []
    if controls['ELITE_PLANET_GPU_EXPERIMENT'] != '1':
        skipped.extend({'classname': 'EliteCoreTests.PlanetGPUShaderTests', 'name': name,
                        'reason': None} for name in GPU_OPT_IN)
    if not (controls['ELITE_NATIVE_WORK_CONTINUATION'] == '1' and bool(source)):
        skipped.append({'classname': 'EliteCoreTests.NativeMultiBatchRuntimeTests',
                        'name': DIAGNOSTIC_METHOD, 'reason': DIAGNOSTIC_REASON})
    return {'controls': controls, 'declarations': {name: digest(root / name)
            for name in (gpu_path, diagnostic_path)}, 'expected_skips': skipped}


def selected_opt_in_skips(identity, methods):
    selected = {xml_identity(method) for method in methods}
    return {(entry['classname'], entry['name']): entry['reason']
            for entry in identity.get('opt_in_policy', {}).get('expected_skips', [])
            if (entry['classname'], entry['name']) in selected}


def inspect_xml(path, expected, expected_skips=None):
    """Reconcile every ID; allow only exact source-bound inactive opt-in outcomes."""
    expected_skips = expected_skips or {}
    root = ET.parse(path).getroot()
    cases = list(root.iter('testcase'))
    actual = [(case.attrib.get('classname', ''), case.attrib.get('name', '')) for case in cases]
    if Counter(actual) != Counter(xml_identity(method) for method in expected) or len(set(actual)) != len(actual):
        raise ValueError('XML does not match the exact batch selection')
    if any(list(root.iter(tag)) for tag in ('failure', 'error')):
        raise ValueError('Batch XML contains unsuccessful outcomes')
    observed_skips = {}
    for case, identifier in zip(cases, actual):
        skipped = list(case.iter('skipped'))
        if skipped:
            if len(skipped) != 1:
                raise ValueError('Duplicate skip outcome')
            observed_skips[identifier] = skipped[0].text
        else:
            elapsed = float(case.attrib.get('time', 'nan'))
            if not math.isfinite(elapsed) or elapsed < 0:
                raise ValueError('XML testcase has no finite completed duration')
    if observed_skips != expected_skips:
        raise ValueError('Unexpected, enabled or missing source-declared opt-in skip')
    for node in root.iter():
        if node.tag in ('testsuite', 'testsuites'):
            descendants = list(node.iter('testcase'))
            skipped_count = sum(bool(list(case.iter('skipped'))) for case in descendants)
            # Swift Testing versions count either all methods or only executed methods.
            if 'tests' in node.attrib and int(node.attrib['tests']) not in (
                    len(descendants), len(descendants) - skipped_count):
                raise ValueError('XML test count is inconsistent')
            if 'skipped' in node.attrib and int(node.attrib['skipped']) != skipped_count:
                raise ValueError('XML skipped count is inconsistent')
        for key in ('failures', 'errors', 'disabled'):
            if key in node.attrib and int(node.attrib[key]) != 0:
                raise ValueError('Batch XML declares unsuccessful outcomes')
    return expected


def owned_evidence(path):
    """Read only physical, owned, non-publicly-writable qualification evidence."""
    if (any(parent.is_symlink() for parent in (path, *path.parents))
            or path.stat().st_uid != os.getuid() or path.stat().st_mode & 0o022):
        raise ValueError('Qualification evidence must be physical, owned and protected')


def copy_report(source, destination):
    """Keep durable attempts immutable but make derived checkout reports disposable."""
    for path in [source, *source.rglob('*')]:
        owned_evidence(path)
    shutil.copytree(source, destination, copy_function=shutil.copyfile)
    destination.chmod(0o700)
    for path in destination.rglob('*'):
        path.chmod(0o700 if path.is_dir() else 0o600)


def legacy_requalification(attempt, identity, methods):
    """Attest an exit-zero legacy run; never rewrite its failed validator receipt."""
    for path in [attempt, attempt / 'start.json', attempt / 'result.json', attempt / 'test.log']:
        owned_evidence(path)
    prior = json.loads((attempt / 'result.json').read_text())
    start = json.loads((attempt / 'start.json').read_text())
    old = prior['identity']
    if (identity['mode'] != 'thread' or old['schema'] != 1 or identity['schema'] != 2
            or old['runner'] != LEGACY_VALIDATION_INPUTS['Tools/CI/sanitizer_checkpoints.py']
            or prior['status'] != 'failed' or prior['exit_code'] != 0
            or prior.get('reason') != 'Batch XML contains unsuccessful outcomes'
            or start['identity'] != old or start['methods'] != methods or prior['methods'] != methods
            or start['head'] != prior['tested_head'] or start['command'] != prior['command']
            or not re.fullmatch(r'[0-9a-f]{40}', prior['tested_head'])
            or methods != identity['inventory']):
        raise ValueError('Not an eligible completed legacy validator-only rejection')
    if set(identity) != set(old) | {'opt_in_policy'}:
        raise ValueError('Legacy identity fields changed unexpectedly')
    for key in set(old) - {'schema', 'runner', 'inputs'}:
        if old[key] != identity[key]:
            raise ValueError('Tested executable, environment, selection or toolchain changed: ' + key)
    if prior['command'] != batch_command(old['swift_executable'], old['flags'], 'thread', attempt, methods, True):
        raise ValueError('Legacy command is not the full original concurrent TSAN command')
    changed = {name for name in set(old['inputs']) | set(identity['inputs'])
               if old['inputs'].get(name) != identity['inputs'].get(name)}
    if not changed <= set(LEGACY_VALIDATION_INPUTS):
        raise ValueError('Executable inputs changed outside the validator-only repair')
    if any(old['inputs'].get(name) != value for name, value in LEGACY_VALIDATION_INPUTS.items()):
        raise ValueError('Legacy validator source identity is not the reviewed version')
    if identity['inputs'].get('Tools/CI/sanitizer_checkpoints.py') != identity['runner']:
        raise ValueError('Current validator identity is inconsistent')
    if any(identity['inputs'].get(name) != value
           for name, value in identity['opt_in_policy']['declarations'].items()):
        raise ValueError('Opt-in declaration source identity changed')
    controls = identity['opt_in_policy']['controls']
    if (controls['ELITE_PLANET_GPU_EXPERIMENT'] == '1'
            or (controls['ELITE_NATIVE_WORK_CONTINUATION'] == '1'
                and controls['continuation_source_nonempty'])):
        raise ValueError('Enabled opt-in requirements cannot reuse disabled outcomes')
    expected = selected_opt_in_skips(identity, methods)
    exact = {('EliteCoreTests.PlanetGPUShaderTests', name): None for name in GPU_OPT_IN}
    exact[('EliteCoreTests.NativeMultiBatchRuntimeTests', DIAGNOSTIC_METHOD)] = DIAGNOSTIC_REASON
    if expected != exact:
        raise ValueError('Legacy requalification requires exactly the six declared opt-ins')
    report = prior['report']
    if report not in ('tests.xml', 'tests-swift-testing.xml'):
        raise ValueError('Unexpected legacy XML path')
    owned_evidence(attempt / report)
    inspect_xml(attempt / report, methods, expected)
    log = (attempt / 'test.log').read_text(errors='replace')
    if (any(marker in log for marker in ERRORS)
            or not re.search(r'Test run with ' + str(len(methods)) + r' tests in [0-9]+ suites? passed after ', log)):
        raise ValueError('Legacy execution has no clean complete terminal log')
    evidence = ['start.json', 'result.json', 'test.log', report]
    return {'attempt': str(attempt), 'original_status': prior['status'],
            'original_checker': old['runner'], 'original_reason': prior['reason'],
            'tested_head': prior['tested_head'], 'tested_identity': old,
            'evidence': {name: digest(attempt / name) for name in evidence},
            'new_policy': identity['runner'], 'validator_only_changed_inputs': sorted(changed),
            'original_opt_in_environment': 'Raw values were not captured and are not reconstructed.',
            'applicability_proof': 'Exactly six source-declared framework skips prove the guards were inactive; their controls occur only in these gates and the unexecuted private diagnostic.',
            'executed_methods': len(methods) - len(exact), 'source_declared_opt_in_skips': len(exact)}


def requalify_completed(prior_attempt, batch_root, identity, methods, head):
    """Create a separate reviewed-policy attestation; execute no test bodies."""
    prior_attempt = Path(prior_attempt)
    proof = legacy_requalification(prior_attempt, identity, methods)
    prior = json.loads((prior_attempt / 'result.json').read_text())
    attempt = batch_root / str(uuid.uuid4())
    owned_directory(attempt)
    for name in ['test.log', *sorted(path.name for path in prior_attempt.glob('*.xml'))]:
        owned_evidence(prior_attempt / name)
        shutil.copyfile(prior_attempt / name, attempt / name)
    receipt = {'tested_head': proof['tested_head'], 'accepted_head': head,
               'identity': identity, 'methods': methods, 'command': prior['command'],
               'exit_code': prior['exit_code'], 'wall_seconds': prior['wall_seconds'],
               'status': 'requalified', 'report': prior['report'], 'requalification': proof,
               'executed_methods': proof['executed_methods'],
               'source_declared_opt_in_skips': proof['source_declared_opt_in_skips'],
               'outputs': {path.name: digest(path) for path in attempt.iterdir()},
               'qualification': 'Existing exit-zero execution revalidated under the corrected opt-in policy; no new test execution and no relabelling of the original failed receipt.'}
    atomic_json(attempt / 'result.json', receipt)
    for path in attempt.iterdir():
        path.chmod(0o400)
    attempt.chmod(0o500)
    return attempt


def successful_attempt(path, identity, methods):
    """Reuse only an immutable complete success with matching inputs and outputs."""
    try:
        if (path.is_symlink() or path.stat().st_uid != os.getuid()
                or path.stat().st_mode & 0o022):
            return None
        result_path = path / 'result.json'
        if (result_path.is_symlink() or result_path.stat().st_uid != os.getuid()
                or result_path.stat().st_mode & 0o022):
            return None
        receipt = json.loads(result_path.read_text())
        if (receipt['identity'] != identity or receipt['methods'] != methods
                or receipt['exit_code'] != 0 or receipt['status'] not in ('passed', 'requalified')
                or not re.fullmatch(r'[0-9a-f]{40}', receipt['tested_head'])):
            return None
        for name, value in receipt['outputs'].items():
            file = path / name
            if (name not in ('test.log', 'tests.xml', 'tests-swift-testing.xml') or file.is_symlink()
                    or file.stat().st_uid != os.getuid() or file.stat().st_mode & 0o022
                    or digest(file) != value):
                return None
        if (receipt['report'] not in ('tests.xml', 'tests-swift-testing.xml')
                or set(receipt['outputs']) != {'test.log'} | {file.name for file in path.glob('*.xml')}
                or receipt['report'] not in receipt['outputs']):
            return None
        inspect_xml(path / receipt['report'], methods, selected_opt_in_skips(identity, methods))
        if receipt['status'] == 'requalified':
            proof = legacy_requalification(Path(receipt['requalification']['attempt']), identity, methods)
            if proof != receipt['requalification']:
                return None
        if any(marker in (path / 'test.log').read_text(errors='replace') for marker in ERRORS):
            return None
        return receipt
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError):
        return None


def executable_inputs(root, scratch):
    """Bind source, resources, tests, dependency sources and all maintained build tools."""
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
    selected = [p for p in tracked if p and (p.startswith(('Sources/', 'Tests/', 'Tools/',
                'script/', '.github/')) or p in ('Package.swift', 'Package.resolved', 'Makefile'))]
    result = {}
    for name in selected:
        path = root / name
        if path.is_symlink():
            raise ValueError('Executable inputs must not be symbolic links')
        result[name] = digest(path)
    dependencies = root / scratch / 'checkouts'
    if dependencies.exists():
        for directory, names, files in os.walk(dependencies, followlinks=False):
            names[:] = sorted(name for name in names if name != '.git')
            for name in names + sorted(files):
                path = Path(directory) / name
                if path.is_symlink():
                    raise ValueError('Dependency input must not be a symbolic link')
                if path.is_file():
                    result[str(path.relative_to(root))] = digest(path)
    return result


def output(command, root, environment, lock):
    return subprocess.check_output(command, cwd=root, env=environment,
                                   stderr=subprocess.PIPE, text=True,
                                   pass_fds=(lock.fileno(),), start_new_session=True).strip()


def batch_command(swift, flags, mode, attempt, methods, full_concurrent=False):
    """Keep TSAN parallel internally; only explicit full-concurrent mode is unfiltered."""
    command = [swift, 'test', *flags, '--skip-build']
    if mode == 'address':
        command.append('--no-parallel')
    command += ['--xunit-output', str(attempt / 'tests.xml')]
    if not full_concurrent:
        patterns = set()
        for method in methods:
            module, components = identifier(method)
            if len(components) > 1:
                patterns.add(re.escape(module + '.' + components[0]) + '/')
            else:
                patterns.add(re.escape(module + '.' + components[0]) + r'(?:/[^/]+:[0-9]+:[0-9]+)?$')
        command += ['--filter', '^(?:' + '|'.join(sorted(patterns)) + ')']
    return command


def ensure_no_live_tests():
    """A disconnected legacy executor is still the owner until its helper exits."""
    from native_runner import require_diagnostic_custody_clear
    require_diagnostic_custody_clear()
    processes = subprocess.check_output(['ps', '-axo', 'pid=,command='], text=True)
    for line in processes.splitlines():
        if ('swiftpm-testing-helper' in line
                and '.xctest/Contents/MacOS/EliteCoreTests' in line):
            raise ValueError('An Elite test helper is still active; no replacement started')


def progress(message):
    """Checkpoint publication must survive a disconnected log reader."""
    try:
        print(message, flush=True)
    except BrokenPipeError:
        sys.stdout = open(os.devnull, 'w')


def build_and_discover(root, swift, flags, environment, lock, report):
    started = time.monotonic()
    stage = 'build'
    try:
        with (report / 'build.log').open('wb') as log:
            subprocess.run([swift, 'build', '--build-tests', *flags], cwd=root, env=environment,
                           stdout=log, stderr=subprocess.STDOUT, check=True,
                           pass_fds=(lock.fileno(),), start_new_session=True)
        build_wall = time.monotonic() - started
        stage = 'discovery'
        listing = output([swift, 'test', *flags, 'list', '--skip-build'], root, environment, lock)
        (report / 'discovery.log').write_text(listing + '\n')
        methods = inventory(listing)
        bins = output([swift, 'build', *flags, '--show-bin-path'], root, environment, lock)
        images = [image for image in sorted(Path(bins).glob('*.xctest/Contents/MacOS/*')) if image.is_file()]
        if len(images) != 1:
            raise ValueError('Expected one actual sanitizer test image')
        return images[0], methods, build_wall
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        atomic_json(report / 'phase-failure.json', {'status': 'failed', 'failure_kind': stage,
                    'reason': str(error), 'exit_code': getattr(error, 'returncode', None),
                    'wall_seconds': time.monotonic() - started})
        raise


def run_mode(mode, cache, target=100, requalify_attempt=None, full_concurrent=False):
    """Build/discover once, then execute or reuse each fully reconciled batch."""
    root = ROOT
    owned_directory(cache)
    lock_path = cache / 'executor.lock'
    if lock_path.is_symlink():
        raise ValueError('Executor lock must be physical')
    descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'a') as lock:
        if (os.fstat(lock.fileno()).st_uid != os.getuid()
                or os.fstat(lock.fileno()).st_mode & 0o022):
            raise ValueError('Executor lock must be owned')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        ensure_no_live_tests()
        environment = runtime_child_environment(os.environ)
        if mode == 'address':
            environment['ASAN_OPTIONS'] = 'detect_leaks=0'
        swift = shutil.which('swift')
        if swift is None:
            raise ValueError('Swift toolchain is unavailable')
        scratch = '.build/tsan' if mode == 'thread' else '.build/asan'
        flags = ['--scratch-path', scratch, '--sanitize=' + mode]
        report = root / 'reports/sanitizers' / mode / str(uuid.uuid4())
        report.mkdir(parents=True, exist_ok=True)
        head = output(['git', 'rev-parse', 'HEAD'], root, environment, lock)
        if output(['git', 'status', '--porcelain'], root, environment, lock):
            raise ValueError('Sanitizer checkpoints require a clean committed checkout')
        before = executable_inputs(root, scratch)
        image, methods, build_wall_seconds = build_and_discover(root, swift, flags, environment, lock, report)
        policy = grouping_policy(root, methods, mode, target, full_concurrent)
        identity = {'schema': 3, 'grouping': policy, 'opt_in_policy': opt_in_policy(root, environment), 'inputs': executable_inputs(root, scratch),
                    'runner': digest(Path(__file__)), 'mode': mode, 'flags': flags,
                    'parallel': mode == 'thread', 'architecture': platform.machine(),
                    'swift': output([swift, '--version'], root, environment, lock),
                    'sdk': output(['xcrun', '--show-sdk-version'], root, environment, lock),
                    'swift_executable': swift, 'image_sha256': digest(image),
                    'image_uuid': output(['xcrun', 'dwarfdump', '--uuid', str(image)], root, environment, lock),
                    'environment': runtime_identity(environment), 'inventory': methods,
                    'os_version': {'release': os.uname().release, 'version': os.uname().version}}
        if any(identity['inputs'].get(key) != value for key, value in before.items()):
            raise ValueError('Executable inputs changed during build')
        key = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
        storage = cache / key
        owned_directory(storage)
        batches = partition(methods, mode, target, policy['shared_groups'], full_concurrent)
        plan = {'current_head': head, 'identity_key': key, 'identity': identity, 'batches': batches,
                'packing_target': target,
                'concurrency': ('Separate full concurrent TSAN policy.' if full_concurrent else
                    'Whole-suite groups; TSAN internal parallelism retained, cross-group overlap differs.'),
                'oversized_batches': [i for i, batch in enumerate(batches) if len(batch) > target]}
        (report / 'plan.json').write_text(json.dumps(plan, indent=2) + '\n')
        completed = []
        for index, batch in enumerate(batches):
            batch_root = storage / str(index)
            owned_directory(batch_root)
            reused = next(((attempt, receipt) for attempt in sorted(batch_root.iterdir())
                           if attempt.is_dir() and (receipt := successful_attempt(attempt, identity, batch))), None)
            if reused is None and requalify_attempt is not None:
                if mode != 'thread' or not full_concurrent or len(batches) != 1:
                    raise ValueError('Explicit legacy requalification is limited to full TSAN mode')
                attempt = requalify_completed(requalify_attempt, batch_root, identity, batch, head)
                receipt = successful_attempt(attempt, identity, batch)
                if receipt is None:
                    raise ValueError('Requalification receipt could not be verified')
                reused = (attempt, receipt)
            if reused is not None:
                attempt, receipt = reused
            else:
                attempt = batch_root / str(uuid.uuid4())
                owned_directory(attempt)
                command = batch_command(swift, flags, mode, attempt, batch, full_concurrent)
                atomic_json(attempt / 'start.json', {'head': head, 'identity': identity,
                            'methods': batch, 'command': command, 'started_utc': time.time()})
                started = time.monotonic()
                with (attempt / 'test.log').open('xb') as log:
                    result = subprocess.run(command, cwd=root, env=environment, stdout=log,
                                            stderr=subprocess.STDOUT, pass_fds=(lock.fileno(),),
                                            start_new_session=True)
                actual_xml = attempt / 'tests-swift-testing.xml'
                if not actual_xml.exists():
                    actual_xml = attempt / 'tests.xml'
                receipt = {'tested_head': head, 'identity': identity, 'methods': batch,
                           'command': command, 'exit_code': result.returncode,
                           'wall_seconds': time.monotonic() - started, 'status': 'failed',
                           'report': actual_xml.name, 'outputs': {}}
                failure_kind = 'test-process'
                try:
                    if result.returncode:
                        text = (attempt / 'test.log').read_text(errors='replace')
                        if result.returncode < 0 or 'unexpected signal' in text or any(marker in text for marker in ERRORS):
                            failure_kind = 'runtime-diagnostic-or-signal'
                        raise ValueError('Sanitizer process did not exit successfully')
                    failure_kind = 'evidence-validation'
                    inspect_xml(actual_xml, batch, selected_opt_in_skips(identity, batch))
                    if any(marker in (attempt / 'test.log').read_text(errors='replace') for marker in ERRORS):
                        failure_kind = 'sanitizer-diagnostic'
                        raise ValueError('Sanitizer reported an error')
                    if executable_inputs(root, scratch) != identity['inputs'] or digest(image) != identity['image_sha256']:
                        raise ValueError('Executable inputs changed during test execution')
                    receipt.update(executed_methods=len(batch) - len(selected_opt_in_skips(identity, batch)),
                                   source_declared_opt_in_skips=len(selected_opt_in_skips(identity, batch)),
                                   status='passed', outputs={file.name: digest(file)
                                   for file in [attempt / 'test.log', *sorted(attempt.glob('*.xml'))]})
                except (ValueError, OSError, ET.ParseError) as error:
                    receipt['reason'] = str(error)
                    receipt['failure_kind'] = failure_kind
                atomic_json(attempt / 'result.json', receipt)
                for file in attempt.iterdir():
                    file.chmod(0o400)
                attempt.chmod(0o500)
                if receipt['status'] != 'passed':
                    copy_report(attempt, report / ('failed-batch-' + str(index)))
                    atomic_json(report / 'phase-failure.json', {'status': 'failed', 'batch': index,
                                'failure_kind': receipt['failure_kind'], 'reason': receipt['reason'],
                                'exit_code': receipt['exit_code'], 'test_wall_seconds': receipt['wall_seconds'],
                                'build_wall_seconds': build_wall_seconds, 'completed_batches': completed})
                    raise ValueError('Sanitizer batch failed; original attempt retained: ' + str(attempt))
            copy_report(attempt, report / ('batch-' + str(index)))
            completed.append({'batch': index, 'tested_head': receipt['tested_head'],
                              'current_head': head, 'reused': reused is not None,
                              'attempt': str(attempt), 'methods': batch, 'outcome_status': receipt['status'],
                              'test_wall_seconds': receipt['wall_seconds'],
                              'executed_methods': receipt.get('executed_methods', len(batch)),
                              'source_declared_opt_in_skips': receipt.get('source_declared_opt_in_skips', 0),
                              'outputs': receipt['outputs']})
            progress(f'{mode}: batch {index + 1}/{len(batches)} qualified '
                     f'({receipt.get("executed_methods", len(batch))} executed; '
                     f'{receipt.get("source_declared_opt_in_skips", 0)} declared opt-ins inactive; '
                     f'{len(batch)} IDs accounted)')
        if (executable_inputs(root, scratch) != identity['inputs']
                or digest(image) != identity['image_sha256']
                or output(['git', 'rev-parse', 'HEAD'], root, environment, lock) != head
                or output(['git', 'status', '--porcelain'], root, environment, lock)):
            raise ValueError('Checkout or executable inputs changed before mode completion')
        summary = {'current_head': head, 'status': 'passed', 'identity': identity,
                   'complete_inventory': methods, 'batches': completed,
                   'executed_methods': sum(batch['executed_methods'] for batch in completed),
                   'source_declared_opt_in_skips': sum(batch['source_declared_opt_in_skips'] for batch in completed),
                   'unexpected_skips': 0,
                   'build_wall_seconds': build_wall_seconds,
                   'executed_test_wall_seconds': sum(batch['test_wall_seconds'] for batch in completed if not batch['reused']),
                   'reused_original_test_wall_seconds': sum(batch['test_wall_seconds'] for batch in completed if batch['reused']),
                   'qualification': 'All applicable methods completed; declared opt-ins are explicitly unexecuted. Coverage, leaks, review and hosted checks remain separate.'}
        (report / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['thread', 'address'])
    parser.add_argument('--cache', type=Path, default=Path.home() / 'Library/EliteNativeCI/sanitizer-checkpoints')
    parser.add_argument('--target', type=int, default=100, help='Soft method target; suites/shared groups never split')
    parser.add_argument('--full-concurrent', action='store_true', help='Separate unpartitioned TSAN coverage policy')
    parser.add_argument('--requalify-attempt', type=Path,
                        help='Explicitly attest a completed legacy process under the corrected opt-in policy')
    args = parser.parse_args()
    if args.full_concurrent and args.mode != 'thread':
        parser.error('Full concurrent policy is only valid for ThreadSanitizer')
    if args.mode != 'thread' and args.requalify_attempt is not None:
        parser.error('Legacy requalification is limited to full ThreadSanitizer mode')
    prior = args.requalify_attempt
    if args.mode == 'thread' and prior is None and os.environ.get('ELITE_TSAN_REQUALIFY_ATTEMPT'):
        prior = Path(os.environ['ELITE_TSAN_REQUALIFY_ATTEMPT'])
    if prior is not None:
        parser.error('Historical requalification is not supported by the new grouping identity; retain old proof separately')
    run_mode(args.mode, args.cache, target=args.target, full_concurrent=args.full_concurrent)


if __name__ == '__main__':
    main()
