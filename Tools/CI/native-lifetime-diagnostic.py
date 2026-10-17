"""Hosted diagnostic only; does not replace CI, leak gates, or release review."""
import hashlib
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import signal
import shlex
import subprocess
import threading
import time

assert os.environ.get('GITHUB_ACTIONS') == 'true', 'Hosted-only diagnostic; no local invocation.'
root = Path(os.environ['GITHUB_WORKSPACE'])
evidence = root / 'reports/hosted-native-lifetime'
evidence.mkdir(parents=True, exist_ok=False)
originals = evidence / 'originals'
originals.mkdir()
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
write = lambda path, value: path.write_text(json.dumps(value, indent=2) + '\n')
known = {}
process_history = {}
native_directory = None
stop = threading.Event()
current = {}
records = []
exit_code = 1
crash_roots = [Path.home() / 'Library/Logs/DiagnosticReports', Path('/Library/Logs/DiagnosticReports')]
baseline = {str(p): sha(p) for base in crash_roots if base.exists() for p in base.glob('*.ips')}
tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
before = {p: sha(root / p) for p in tracked if p}
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root).decode().strip()
write(evidence / 'source-before.json', {'head': head, 'tracked': before})


def parse_process_snapshot(raw):
    rows = {}
    for row in raw.splitlines():
        fields = row.split(None, 9)
        if len(fields) == 10:
            rows[int(fields[0])] = {'parent': int(fields[1]), 'group': int(fields[2]),
                                   'state': fields[3], 'start': ' '.join(fields[4:9]),
                                   'command': fields[9]}
    return rows


def snapshot():
    raw = subprocess.check_output(
        ['ps', '-axo', 'pid=,ppid=,pgid=,stat=,lstart=,command=']).decode()
    return parse_process_snapshot(raw)


def crash_launch_time(value):
    """Apple reports use a space before the UTC offset; accept explicit zoned formats only."""
    if not isinstance(value, str):
        return None
    for pattern in ('%Y-%m-%d %H:%M:%S.%f %z', '%Y-%m-%d %H:%M:%S %z'):
        try:
            return datetime.strptime(value, pattern).timestamp()
        except ValueError:
            pass
    try:
        parsed = datetime.fromisoformat(value)
        return parsed.timestamp() if parsed.tzinfo is not None else None
    except ValueError:
        return None


def remember(pid, row):
    if known.get(pid, {}).get('start') != row['start']:
        process_history.setdefault(pid, []).append(row)
    known[pid] = row


def follow(pid):
    rows = snapshot()
    # Historical or reused PID numbers confer no ownership on their current children.
    selected = {child for child, row in known.items() if child in rows
                and rows[child]['start'] == row['start']}
    while True:
        children = {child for child, row in rows.items() if row['parent'] in selected}
        if children <= selected:
            break
        for child in children - selected:
            remember(child, rows[child])
        selected |= children
    return {child: rows[child] for child in selected}


def monitor(pid):
    while not stop.wait(0.1):
        follow(pid)


def terminate(pid):
    # A test helper may create its own process group. Track actual descendants, not just PGID.
    for signum in (signal.SIGTERM, signal.SIGKILL):
        for child, row in follow(pid).items():
            fresh = snapshot().get(child)
            if fresh is None or fresh['start'] != row['start']:
                continue
            try:
                os.kill(child, signum)
            except ProcessLookupError:
                pass
        deadline = time.monotonic() + 5
        while follow(pid) and time.monotonic() < deadline:
            time.sleep(0.1)


def observe_natural_exit(pid, budget=2.0, interval=0.1):
    """Observe owned identities only. Every persistent state, including Z, remains a failure."""
    started = time.monotonic()
    timeline = []
    while True:
        remaining = follow(pid)
        elapsed = time.monotonic() - started
        timeline.append({'elapsedSeconds': elapsed, 'ownedProcesses': remaining})
        if not remaining or elapsed >= budget:
            return {'budgetSeconds': budget, 'intervalSeconds': interval,
                    'durationSeconds': elapsed, 'timeline': timeline,
                    'endReason': 'empty' if not remaining else 'deadline',
                    'remainingAfterNaturalExit': remaining,
                    'signalCleanupRequired': bool(remaining)}
        time.sleep(min(interval, budget - elapsed))


def run(name, command, timeout):
    stop.clear()
    started = time.monotonic()
    log = evidence / (name + '.log')
    with log.open('x') as output:
        process = subprocess.Popen(command, cwd=root, stdout=output, stderr=subprocess.STDOUT,
                                   start_new_session=True)
        row = snapshot().get(process.pid)
        if row is not None:
            remember(process.pid, row)
        follow(process.pid)
        watcher = threading.Thread(target=monitor, args=(process.pid,))
        watcher.start()
        timed_out = False
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            terminate(process.pid)
            process.wait(timeout=10)
            code = 124
        finally:
            stop.set()
            watcher.join(timeout=5)
        if timed_out:
            natural_exit = {'skipped': 'timed_out', 'timeline': []}
            remaining = follow(process.pid)
        else:
            natural_exit = observe_natural_exit(process.pid)
            remaining = natural_exit['remainingAfterNaturalExit']
        if remaining:
            terminate(process.pid)
            code = code or 125
        remaining_after_cleanup = follow(process.pid)
    record = {'command': command, 'parentPID': process.pid, 'exitCode': code,
              'timedOut': timed_out, 'timeoutSeconds': timeout,
              'durationSeconds': time.monotonic() - started, 'rawSHA256': sha(log),
              'naturalExitObservation': natural_exit,
              'remainingBeforeCleanup': remaining, 'remainingAfterCleanup': remaining_after_cleanup}
    records.append(record)
    write(evidence / (name + '.json'), record)
    assert not remaining_after_cleanup, 'Diagnostic descendants remain alive.'
    return code, log.read_text()


try:
    assert head == os.environ['ELITE_DIAGNOSTIC_HEAD'], 'Exact PR/dispatch head required.'
    protected_base = 'a804f245c4baf3668b22393206a43a048465739a'
    diagnostic_test = 'Tests/EliteCoreTests/NativeLifetimeDiagnosticTests.swift'
    allowed = {diagnostic_test, '.github/workflows/native-lifetime-diagnostic.yml',
               'Tools/CI/native-lifetime-diagnostic.py', '.github/workflows/ci.yml',
               'Tools/CI/capture-quality.py'}
    subprocess.run(['git', 'merge-base', '--is-ancestor', protected_base, head],
                   cwd=root, check=True)
    changed_from_base = set(subprocess.check_output(
        ['git', 'diff', '--name-only', protected_base, head], cwd=root).decode().splitlines())
    assert changed_from_base == allowed, 'Protected a804 source differs outside the five reviewed diagnostic/CI paths.'
    assert sha(root / diagnostic_test) == 'a4845b3a70ac8a4cb68eb5bc6d2bbe2147a7bf10ddf253a23c03564812615673'
    assert not subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'],
                                       cwd=root).strip(), 'Committed source required.'
    write(evidence / 'protected-source.json',
          {'head': head, 'productionBase': protected_base,
           'changedPaths': sorted(changed_from_base), 'diagnosticTestSHA256': sha(root / diagnostic_test)})
    metadata = {}
    for name, command in [('os', ['sw_vers']), ('xcode', ['xcodebuild', '-version']),
                          ('swift', ['xcrun', 'swift', '--version']),
                          ('sdk', ['xcrun', '--show-sdk-path']),
                          ('sdkVersion', ['xcrun', '--show-sdk-version']),
                          ('architecture', ['uname', '-m'])]:
        result = subprocess.run(command, cwd=root, capture_output=True, text=True, check=False)
        metadata[name] = {'command': command, 'exitCode': result.returncode,
                          'stdout': result.stdout, 'stderr': result.stderr}
    metadata['developerDirectory'] = os.environ.get('DEVELOPER_DIR')
    metadata['asanOptions'] = os.environ.get('ASAN_OPTIONS')
    metadata['instrumentationOverrides'] = {key: os.environ.get(key)
                                            for key in ['NSZombieEnabled', 'MallocStackLogging']}
    write(evidence / 'environment.json', metadata)
    assert all(value['exitCode'] == 0 for value in metadata.values() if isinstance(value, dict)
               and 'exitCode' in value)
    assert re.search(r'ProductVersion:\s*15\.', metadata['os']['stdout'])
    assert metadata['xcode']['stdout'].startswith('Xcode 16.4\n')
    assert os.environ.get('ASAN_OPTIONS') == 'detect_leaks=0'
    assert not any(metadata['instrumentationOverrides'].values())
    scratch = '.build/hosted-native-lifetime-asan'
    exit_code, catalogue = run('01-compile-discovery',
                              ['xcrun', 'swift', 'test', 'list', '--scratch-path', scratch,
                               '--sanitize=address'], 600)
    if exit_code == 0:
        name = 'NativeViewTests/nativeLifetimeDiagnosticOpenJoinFrameDrawTeardown()'
        matches = [line for line in catalogue.splitlines() if line.strip().endswith(name)]
        assert len(matches) == 1, 'Focused native test must exist exactly once.'
        os.environ['ELITE_NATIVE_LIFETIME_ARTIFACT_DIRECTORY'] = str(originals)
        os.environ['ELITE_VALIDATION_SOURCE_SHA'] = head
        exit_code, raw = run('02-native-asan',
                             ['xcrun', 'swift', 'test', '--scratch-path', scratch,
                              '--sanitize=address', '--skip-build', '--no-parallel',
                              '--filter', 'NativeViewTests/nativeLifetimeDiagnosticOpenJoinFrameDrawTeardown'], 300)
        if exit_code == 0:
            assert re.search(r'Test run with 1 test(?: in 1 suite)? passed', raw)
            reported = re.findall(r'^ELITE_NATIVE_LIFETIME_ARTIFACT_DIRECTORY=(.+)$', raw, re.MULTILINE)
            assert len(reported) == 1, 'Exactly one native namespace must be reported.'
            native_directory = Path(reported[0]).resolve(strict=True)
            assert native_directory.parent == originals.resolve(strict=True)
            assert native_directory.name.startswith('native-lifetime-')
            assert len(list(originals.iterdir())) == 1
            assert len(list(native_directory.glob('cycle-*.json'))) == 24
            assert len(list(native_directory.glob('*.png'))) == 3
            process = json.loads((native_directory / 'process.json').read_text())
            assert process['source'] == head and process['productionBase'] == protected_base
            assert process['iterations'] == 3
            assert Path(process['artifactDirectory']).resolve(strict=True) == native_directory
except Exception as error:
    write(evidence / 'diagnostic-error.json', {'type': type(error).__name__, 'detail': str(error)})
    exit_code = exit_code or 1
finally:
    if native_directory is None:
        children = [path for path in originals.iterdir()
                    if path.is_dir() and not path.is_symlink() and path.name.startswith('native-lifetime-')]
        if len(children) == 1:
            native_directory = children[0].resolve(strict=True)
    native_process = None
    if native_directory is not None and (native_directory / 'process.json').exists():
        native_process = json.loads((native_directory / 'process.json').read_text())
    crashes = {}
    # CrashReporter can finish writing shortly after the crashing process exits. This is
    # bounded artifact collection, not a rerun of the build or test.
    for _ in range(7):
        for base in crash_roots:
            if not base.exists():
                continue
            for path in base.glob('*.ips'):
                digest = sha(path)
                if baseline.get(str(path)) == digest:
                    continue
                documents = []
                raw = path.read_text(errors='replace')
                decoder = json.JSONDecoder()
                offset = 0
                try:
                    while offset < len(raw):
                        while offset < len(raw) and raw[offset].isspace():
                            offset += 1
                        if offset == len(raw):
                            break
                        value, offset = decoder.raw_decode(raw, offset)
                        documents.append(value)
                except ValueError:
                    documents = []
                payload = next((value for value in documents if isinstance(value, dict)
                                and isinstance(value.get('pid'), int)
                                and isinstance(value.get('procPath'), str)), None)
                matched = False
                detail = {'name': path.name, 'sha256': digest, 'matchedActualProcess': False}
                if payload is not None:
                    pid = payload['pid']
                    binary = os.path.realpath(payload['procPath'])
                    launch = payload.get('procLaunch')
                    detail.update({'crashedPID': pid, 'binary': binary, 'launch': launch})
                    launch_time = crash_launch_time(launch)
                    for record in process_history.get(pid, []):
                        observed = datetime.strptime(record['start'], '%a %b %d %H:%M:%S %Y').timestamp()
                        arguments = shlex.split(record['command'])
                        observed_binary = os.path.realpath(arguments[0]) if arguments else None
                        if (native_process is not None and native_process.get('pid') == pid
                                and native_process.get('arguments')):
                            observed_binary = os.path.realpath(native_process['arguments'][0])
                        if (launch_time is not None and abs(launch_time - observed) < 1.1
                                and observed_binary == binary):
                            matched = True
                            break
                if matched:
                    destination = evidence / 'matched-crashes'
                    destination.mkdir(exist_ok=True)
                    target = destination / (digest[:16] + '-' + path.name)
                    shutil.copy2(path, target)
                    detail.update({'matchedActualProcess': True,
                                   'retained': str(target.relative_to(evidence))})
                # Unmatched reports retain attribution metadata/hash only; no unrelated pixels,
                # stacks or original application reports are uploaded.
                crashes[str(path)] = detail
        time.sleep(0.5)
    write(evidence / 'crash-originals.json', list(crashes.values()))
    write(evidence / 'observed-processes.json', process_history)
    after_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root).decode().strip()
    changed = [path for path, digest in before.items() if sha(root / path) != digest]
    status = {'head': head, 'headUnchanged': after_head == head, 'changedTrackedInputs': changed,
              'exitCode': exit_code, 'attempts': records,
              'qualification': 'Focused hosted diagnostic only. No full CI, cause, leak, coverage, review or release claim.'}
    if changed or after_head != head:
        status['exitCode'] = exit_code = 126
    write(evidence / 'summary.json', status)
    write(evidence / 'originals-manifest.json',
          {str(path.relative_to(evidence)): sha(path) for path in evidence.rglob('*') if path.is_file()})
print(json.dumps({'exitCode': exit_code, 'source': head, 'attempts': len(records)}))
raise SystemExit(exit_code)
