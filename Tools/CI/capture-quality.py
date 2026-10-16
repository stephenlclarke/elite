"""Run the original make ci once and retain raw output and attributed crash originals."""
import hashlib
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import signal
import shlex
import sys
import subprocess
import threading
import time

assert os.environ.get('GITHUB_ACTIONS') == 'true', 'Hosted-only diagnostic; no local invocation.'
root = Path(os.environ['GITHUB_WORKSPACE'])
evidence = root / 'reports/quality-runtime'
evidence.mkdir(parents=True, exist_ok=False)
originals = evidence / 'originals'
originals.mkdir()
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
write = lambda path, value: path.write_text(json.dumps(value, indent=2) + '\n')
known = {}
process_history = {}
native_directory = None
ownership_lock = threading.RLock()
monitor_errors = []
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


def snapshot():
    rows = {}
    raw = subprocess.check_output(['ps', '-axo', 'pid=,ppid=,pgid=,lstart=,command=']).decode()
    for row in raw.splitlines():
        fields = row.split(None, 8)
        if len(fields) == 9:
            rows[int(fields[0])] = {'parent': int(fields[1]), 'group': int(fields[2]),
                                   'start': ' '.join(fields[3:8]), 'command': fields[8]}
    return rows


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
            follow(pid)
    except Exception as error:
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


def run(name, command):
    stop.clear()
    started = time.monotonic()
    log = evidence / (name + '.log')
    with log.open('xb') as output:
        process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, start_new_session=True)
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
        remaining = follow(process.pid)
        if remaining:
            terminate(process.pid)
            code = code or 125
        reader.join(timeout=10)
        remaining_after_cleanup = follow(process.pid)
    record = {'command': command, 'parentPID': process.pid, 'makeExitCode': process.returncode,
              'exitCode': code, 'interrupted': interrupted,
              'durationSeconds': time.monotonic() - started, 'rawSHA256': sha(log),
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
                          ('sdk', ['xcrun', '--show-sdk-path']),
                          ('sdkVersion', ['xcrun', '--show-sdk-version']),
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
    native_process = None
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
              'qualification': 'Original make ci exit status retained. Artifacts do not waive failed tests/sanitizers/leaks/review.'}
    if changed or after_head != head:
        status['exitCode'] = exit_code = 126
    write(evidence / 'summary.json', status)
    write(evidence / 'originals-manifest.json',
          {str(path.relative_to(evidence)): sha(path) for path in evidence.rglob('*') if path.is_file()})
print(json.dumps({'exitCode': exit_code, 'source': head, 'attempts': len(records)}))
raise SystemExit(exit_code)
