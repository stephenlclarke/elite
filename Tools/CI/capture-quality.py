"""Run the original make ci once and retain raw output and attributed crash originals."""
import json
import os
from pathlib import Path
import re
import signal
import sys
import subprocess
import threading
import time

from crash_artifacts import (ArtifactBudget, OwnedFaultStack, collect_reports, report_snapshot,
                             cleanup_owned_identity, fault_capture_exit_code,
                             retain_test_images, runtime_child_environment, sha as streaming_sha)

assert os.environ.get('GITHUB_ACTIONS') == 'true', 'Hosted-only diagnostic; no local invocation.'
root = Path(os.environ['GITHUB_WORKSPACE'])
evidence = root / 'reports/quality-runtime'
evidence.mkdir(parents=True, exist_ok=False)
originals = evidence / 'originals'
originals.mkdir()
sha = streaming_sha
write = lambda path, value: path.write_text(json.dumps(value, indent=2) + '\n')
known = {}
process_history = {}
ownership_lock = threading.RLock()
monitor_errors = []
stop = threading.Event()
current = {}
records = []
exit_code = 1
budget = ArtifactBudget()
crash_roots = [Path.home() / 'Library/Logs/DiagnosticReports', Path('/Library/Logs/DiagnosticReports')]
baseline = report_snapshot(crash_roots)
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


def remember(pid, row):
    if known.get(pid, {}).get('start') != row['start']:
        process_history.setdefault(pid, []).append(row)
    known[pid] = row


def follow(pid):
    with ownership_lock:
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
    try:
        while not stop.wait(0.1):
            owned = follow(pid)
            fault_stack.consider(owned)
            fault_stack.poll()
    except Exception as error:
        fault_stack._interrupt(error)
        monitor_errors.append({'type': type(error).__name__, 'detail': str(error)})
        stop.set()


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


fault_stack = OwnedFaultStack(
    root, evidence, budget, snapshot, lambda identity: cleanup_owned_identity(identity, snapshot))


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


def run(name, command):
    stop.clear()
    started = time.monotonic()
    log = evidence / (name + '.log')
    child_environment = runtime_child_environment(os.environ)
    with log.open('xb') as output:
        process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, start_new_session=True,
                                   env=child_environment)
        row = snapshot().get(process.pid)
        if row is not None:
            remember(process.pid, row)
        follow(process.pid)

        def forward():
            while True:
                chunk = process.stdout.read1(65536)
                if not chunk:
                    return
                output.write(chunk)
                output.flush()
                try:
                    sys.stdout.buffer.write(chunk)
                    sys.stdout.buffer.flush()
                except BrokenPipeError:
                    pass

        watcher = threading.Thread(target=monitor, args=(process.pid,))
        reader = threading.Thread(target=forward)
        watcher.start()
        reader.start()
        interrupted = False
        try:
            # Preserve the existing workflow's timeout; this wrapper adds no per-test limit.
            code = process.wait()
        except KeyboardInterrupt:
            interrupted = True
            terminate(process.pid)
            process.wait(timeout=10)
            code = 130
        finally:
            stop.set()
            watcher.join(timeout=5)
        diagnostic = fault_stack.finish()
        code = fault_capture_exit_code(code, diagnostic)
        write(evidence / 'owned-fault-stack.json', diagnostic)
        if interrupted:
            natural_exit = {'skipped': 'interrupted', 'timeline': []}
            remaining = follow(process.pid)
        else:
            natural_exit = observe_natural_exit(process.pid)
            remaining = natural_exit['remainingAfterNaturalExit']
        if remaining:
            terminate(process.pid)
            code = code or 125
        reader.join(timeout=10)
        remaining_after_cleanup = follow(process.pid)
    record = {'command': command, 'runtimeBacktrace': child_environment['SWIFT_BACKTRACE'],
              'parentPID': process.pid, 'makeExitCode': process.returncode,
              'exitCode': code, 'interrupted': interrupted,
              'faultStackDiagnostic': diagnostic,
              'durationSeconds': time.monotonic() - started, 'rawSHA256': sha(log),
              'naturalExitObservation': natural_exit,
              'remainingBeforeCleanup': remaining, 'remainingAfterCleanup': remaining_after_cleanup,
              'monitorErrors': list(monitor_errors),
              'observerAlive': watcher.is_alive(), 'readerAlive': reader.is_alive()}
    records.append(record)
    write(evidence / (name + '.json'), record)
    assert not remaining_after_cleanup and not watcher.is_alive() and not reader.is_alive()
    assert not monitor_errors, 'Process observation failed; closure is not qualified.'
    return code


def interrupt(signum, frame):
    raise KeyboardInterrupt


signal.signal(signal.SIGTERM, interrupt)

try:
    assert not subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'],
                                       cwd=root).strip(), 'Committed source required.'
    metadata = {}
    for name, command in [('os', ['sw_vers']), ('xcode', ['xcodebuild', '-version']),
                          ('swift', ['swift', '--version']),
                          ('xcrunSwift', ['xcrun', 'swift', '--version']),
                          ('sdk', ['xcrun', '--sdk', 'macosx', '--show-sdk-path']),
                          ('sdkVersion', ['xcrun', '--sdk', 'macosx', '--show-sdk-version']),
                          ('architecture', ['uname', '-m'])]:
        result = subprocess.run(command, cwd=root, capture_output=True, text=True, check=False)
        metadata[name] = {'command': command, 'exitCode': result.returncode,
                          'stdout': result.stdout, 'stderr': result.stderr}
    write(evidence / 'environment.json', metadata)
    print(json.dumps({'source': head, 'environment': metadata}), flush=True)
    assert all(value['exitCode'] == 0 for value in metadata.values())
    exit_code = run('ci', ['make', 'ci'])
except Exception as error:
    write(evidence / 'capture-error.json', {'type': type(error).__name__, 'detail': str(error)})
    original_exit = records[-1]['makeExitCode'] if records else None
    exit_code = original_exit if original_exit else (exit_code or 1)
finally:
    crashes = []
    audit = {'status': 'not-needed-successful-command',
             'baselineDirectories': baseline['directories']}
    images = []
    if exit_code != 0:
        try:
            # These are actual already-owned helper paths, not a guessed local replacement.
            images = retain_test_images(process_history, root, evidence, head, budget)
            crashes, audit = collect_reports(
                crash_roots, baseline, process_history, evidence, budget, observed_images=images)
        except Exception as error:
            # Artifact capture never replaces the original failing make status.
            audit = {'status': 'capture-error', 'type': type(error).__name__,
                     'detail': str(error), 'baselineDirectories': baseline['directories']}
    write(evidence / 'native-images.json', {'source': head, 'failureOnly': True,
                                           'originalMakeExitCode': records[-1]['makeExitCode'] if records else None,
                                           'captureExitCode': exit_code, 'images': images})
    write(evidence / 'report-discovery.json', audit)
    write(evidence / 'crash-originals.json', crashes)
    write(evidence / 'observed-processes.json', process_history)
    after_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root).decode().strip()
    changed = [path for path, digest in before.items() if sha(root / path) != digest]
    status = {'head': head, 'headUnchanged': after_head == head, 'changedTrackedInputs': changed,
              'exitCode': exit_code, 'attempts': records,
              'qualification': 'Original make ci exit status retained. Artifacts do not waive failed tests/sanitizers/leaks/review.'}
    if changed or after_head != head:
        status['exitCode'] = exit_code = 126
    write(evidence / 'summary.json', status)
    write(evidence / 'originals-manifest.json',
          {str(path.relative_to(evidence)): sha(path) for path in evidence.rglob('*') if path.is_file()})
print(json.dumps({'exitCode': exit_code, 'source': head, 'attempts': len(records)}))
raise SystemExit(exit_code)
