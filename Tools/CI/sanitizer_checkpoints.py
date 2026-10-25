#!/usr/bin/env python3
"""Resume complete sanitizer outcomes without replacing the full concurrent TSAN run."""
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


def partition(methods, mode, target=100):
    """Keep all original TSAN overlap; ASAN packs whole suites without parallelism."""
    if not methods or len(set(methods)) != len(methods) or target < 1:
        raise ValueError('Invalid sanitizer selection')
    if mode == 'thread':
        return [sorted(methods)]
    if mode != 'address':
        raise ValueError('Unknown sanitizer mode')
    suites = {}
    for method in sorted(methods):
        suites.setdefault(group_key(method), []).append(method)
    batches, pending = [], []
    for suite in suites.values():
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
    if prior['command'] != batch_command(old['swift_executable'], old['flags'], 'thread', attempt, methods):
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


def batch_command(swift, flags, mode, attempt, methods):
    """TSAN runs unfiltered; ASAN selects complete suites with bounded arguments."""
    command = [swift, 'test', *flags, '--skip-build']
    if mode == 'address':
        command.append('--no-parallel')
    command += ['--xunit-output', str(attempt / 'tests.xml')]
    if mode == 'address':
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


def run_mode(mode, cache, target=100, requalify_attempt=None):
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
        with (report / 'build.log').open('wb') as log:
            subprocess.run([swift, 'build', '--build-tests', *flags], cwd=root, env=environment,
                           stdout=log, stderr=subprocess.STDOUT, check=True,
                           pass_fds=(lock.fileno(),), start_new_session=True)
        listing = output([swift, 'test', *flags, 'list', '--skip-build'], root, environment, lock)
        (report / 'discovery.log').write_text(listing + '\n')
        methods = inventory(listing)
        bins = output([swift, 'build', *flags, '--show-bin-path'], root, environment, lock)
        images = sorted(Path(bins).glob('*.xctest/Contents/MacOS/*'))
        images = [image for image in images if image.is_file()]
        if len(images) != 1:
            raise ValueError('Expected one actual sanitizer test image')
        image = images[0]
        identity = {'schema': 2, 'opt_in_policy': opt_in_policy(root, environment), 'inputs': executable_inputs(root, scratch),
                    'runner': digest(Path(__file__)), 'mode': mode, 'flags': flags,
                    'parallel': mode == 'thread', 'architecture': platform.machine(),
                    'swift': output([swift, '--version'], root, environment, lock),
                    'sdk': output(['xcrun', '--show-sdk-version'], root, environment, lock),
                    'swift_executable': swift, 'image_sha256': digest(image),
                    'image_uuid': output(['xcrun', 'dwarfdump', '--uuid', str(image)], root, environment, lock),
                    'environment': {key: environment.get(key) for key in (
                        'DEVELOPER_DIR', 'SDKROOT', 'TOOLCHAINS', 'SWIFT_EXEC', 'SWIFT_BACKTRACE',
                        'ASAN_OPTIONS', 'TSAN_OPTIONS', 'DYLD_LIBRARY_PATH',
                        'DYLD_FRAMEWORK_PATH', 'DYLD_INSERT_LIBRARIES')}, 'inventory': methods}
        if any(identity['inputs'].get(key) != value for key, value in before.items()):
            raise ValueError('Executable inputs changed during build')
        key = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
        storage = cache / key
        owned_directory(storage)
        batches = partition(methods, mode, target)
        plan = {'current_head': head, 'identity_key': key, 'identity': identity, 'batches': batches,
                'packing_target': target,
                'concurrency': 'Full original concurrent selection is one indivisible TSAN group.'
                    if mode == 'thread' else 'Original no-parallel mode; suites remain intact.',
                'oversized_batches': [i for i, batch in enumerate(batches) if len(batch) > target]}
        (report / 'plan.json').write_text(json.dumps(plan, indent=2) + '\n')
        completed = []
        for index, batch in enumerate(batches):
            batch_root = storage / str(index)
            owned_directory(batch_root)
            reused = next(((attempt, receipt) for attempt in sorted(batch_root.iterdir())
                           if attempt.is_dir() and (receipt := successful_attempt(attempt, identity, batch))), None)
            if reused is None and requalify_attempt is not None:
                if mode != 'thread' or len(batches) != 1:
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
                command = batch_command(swift, flags, mode, attempt, batch)
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
                try:
                    if result.returncode:
                        raise ValueError('Sanitizer process did not exit successfully')
                    inspect_xml(actual_xml, batch, selected_opt_in_skips(identity, batch))
                    if any(marker in (attempt / 'test.log').read_text(errors='replace') for marker in ERRORS):
                        raise ValueError('Sanitizer reported an error')
                    if executable_inputs(root, scratch) != identity['inputs'] or digest(image) != identity['image_sha256']:
                        raise ValueError('Executable inputs changed during test execution')
                    receipt.update(executed_methods=len(batch) - len(selected_opt_in_skips(identity, batch)),
                                   source_declared_opt_in_skips=len(selected_opt_in_skips(identity, batch)),
                                   status='passed', outputs={file.name: digest(file)
                                   for file in [attempt / 'test.log', *sorted(attempt.glob('*.xml'))]})
                except (ValueError, OSError, ET.ParseError) as error:
                    receipt['reason'] = str(error)
                atomic_json(attempt / 'result.json', receipt)
                for file in attempt.iterdir():
                    file.chmod(0o400)
                attempt.chmod(0o500)
                if receipt['status'] != 'passed':
                    shutil.copytree(attempt, report / ('failed-batch-' + str(index)))
                    raise ValueError('Sanitizer batch failed; original attempt retained: ' + str(attempt))
            shutil.copytree(attempt, report / ('batch-' + str(index)))
            completed.append({'batch': index, 'tested_head': receipt['tested_head'],
                              'current_head': head, 'reused': reused is not None,
                              'attempt': str(attempt), 'methods': batch, 'outcome_status': receipt['status'],
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
                   'qualification': 'All applicable methods completed; declared opt-ins are explicitly unexecuted. Coverage, leaks, review and hosted checks remain separate.'}
        (report / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['thread', 'address'])
    parser.add_argument('--cache', type=Path, default=Path.home() / 'Library/EliteNativeCI/sanitizer-checkpoints')
    parser.add_argument('--requalify-attempt', type=Path,
                        help='Explicitly attest a completed legacy process under the corrected opt-in policy')
    args = parser.parse_args()
    if args.mode != 'thread' and args.requalify_attempt is not None:
        parser.error('Legacy requalification is limited to full ThreadSanitizer mode')
    prior = args.requalify_attempt
    if args.mode == 'thread' and prior is None and os.environ.get('ELITE_TSAN_REQUALIFY_ATTEMPT'):
        prior = Path(os.environ['ELITE_TSAN_REQUALIFY_ATTEMPT'])
    run_mode(args.mode, args.cache, requalify_attempt=prior)


if __name__ == '__main__':
    main()
