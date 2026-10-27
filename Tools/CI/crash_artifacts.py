"""Retain confined failure evidence with explicit process-attribution boundaries."""
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import signal
import shutil
import subprocess
import time
import threading

ARTIFACT_LIMIT = 512 * 1024 * 1024
REPORT_SUFFIXES = {'.ips', '.crash'}
# The optional printer can outlive its timeout; OS and owned debugger evidence remain separate.
RUNTIME_BACKTRACE = ('enable=no,interactive=no,color=no,output-to=stderr,'
                     'threads=crashed,registers=crashed,images=mentioned')


def runtime_child_environment(parent):
    """Disable the optional runtime printer only for the owned CI child."""
    child = dict(parent)
    child['SWIFT_BACKTRACE'] = RUNTIME_BACKTRACE
    return child



FAULT_LOG_LIMIT = 1024 * 1024


def same_process(identity, row):
    """PID alone never authorizes attaching to or cleaning up a process."""
    return row is not None and all(identity[key] == row.get(key) for key in ('start', 'command'))


def cleanup_owned_identity(identity, snapshot, send_signal=os.kill,
                           clock=time.monotonic, sleep=time.sleep):
    """Failure-boundary cleanup: freshly match before every TERM/KILL, never a PID-only kill."""
    for signum in (signal.SIGTERM, signal.SIGKILL):
        if not same_process(identity, snapshot().get(identity['pid'])):
            return
        try:
            send_signal(identity['pid'], signum)
        except ProcessLookupError:
            return
        deadline = clock() + 5
        while same_process(identity, snapshot().get(identity['pid'])) and clock() < deadline:
            sleep(0.1)


def coverage_helper(pid, row, workspace):
    """Only the observed, unfiltered, normal arm64 coverage helper is eligible."""
    argv = arguments(row)
    if not argv or not Path(argv[0]).is_absolute() or Path(argv[0]).name != 'swiftpm-testing-helper':
        return None
    image = Path(workspace) / '.build/arm64-apple-macosx/debug/L337PackageTests.xctest/Contents/MacOS/L337PackageTests'
    expected = [argv[0], '--test-bundle-path', str(image), '--enable-code-coverage',
                str(image), '--testing-library', 'swift-testing']
    if argv != expected:
        image = checkpoint_coverage_image(argv, workspace)
        if image is None:
            return None
    if not row.get('start'):
        return None
    try:
        confined(image, Path(workspace) / '.build')
        if not image.is_file():
            return None
    except (OSError, ValueError):
        return None
    return {'pid': pid, 'start': row['start'], 'command': row['command'], 'arguments': argv}


def checkpoint_coverage_image(argv, workspace):
    """Only the exact normal phase child form and its owned durable attempt qualify."""
    if len(argv) != 10:
        return None
    image = Path(argv[2])
    layouts = [Path(workspace) / '.build' / path for path in (
        'arm64-apple-macosx/debug/L337PackageTests.xctest/Contents/MacOS/L337PackageTests',
        'out/Products/Debug/EliteCoreTests.xctest/Contents/MacOS/EliteCoreTests')]
    if image not in layouts:
        return None
    report = Path(argv[6])
    cache = Path.home() / 'Library/EliteNativeCI/sanitizer-checkpoints/phases'
    try:
        if any(path.is_symlink() for path in (cache, *cache.parents, image, *image.parents)):
            return None
        relative = report.relative_to(cache)
        if (len(relative.parts) != 3 or not re.fullmatch(r'[0-9a-f]{64}', relative.parts[0])
                or not re.fullmatch(r'[0-9a-f-]{36}', relative.parts[1])
                or relative.parts[2] != 'tests-swift-testing.xml'):
            return None
        attempt = confined(report.parent, cache)
        start = confined(attempt / 'start.json', cache)
        for path in (cache, attempt.parent, attempt, start):
            info = path.stat()
            if info.st_uid != os.getuid() or info.st_mode & 0o022:
                return None
        record = json.loads(start.read_text())
        requested = str(attempt / 'tests.xml')
        if (record['identity']['phase'] != 'normal'
                or record['command'] != [record['identity']['swift_executable'], 'test',
                    '--enable-code-coverage', '--skip-build', '--xunit-output', requested]):
            return None
        expected = [argv[0], '--test-bundle-path', str(image), '--enable-code-coverage',
                    '--skip-build', '--xunit-output', str(report), str(image),
                    '--testing-library', 'swift-testing']
        # Swift 6.4.1 retained --skip-build and rewrote XUnit's filename in saved helper evidence.
        if argv != expected or report.is_symlink():
            return None
        return image
    except (OSError, ValueError, KeyError, TypeError):
        return None


def fault_capture_exit_code(code, diagnostic):
    """Keep actual failing status; diagnostic uncertainty can only turn success into failure."""
    if code:
        return code
    if diagnostic['diagnosticallyInterrupted']:
        return 125
    if diagnostic['status'] == 'fault-captured':
        diagnostic.update(status='DIAGNOSTICALLY_INTERRUPTED', diagnosticallyInterrupted=True,
                          detail='A captured fault did not produce a failing make status.')
        return 125
    return code


class OwnedFaultStack:
    """One diagnostic attempt in the existing owned-process observer, never a test runner."""
    def __init__(self, workspace, evidence, budget, snapshot, cleanup, popen=subprocess.Popen):
        self.workspace, self.evidence, self.budget = Path(workspace), Path(evidence), budget
        self.snapshot, self.cleanup, self.popen = snapshot, cleanup, popen
        self.identity = None
        self.observer = None
        self.observer_owned = {}
        self.reader = None
        self.reserved = False
        self.attempted = False
        self.result = {'status': 'no-eligible-helper', 'diagnosticallyInterrupted': False}
        self.log = self.evidence / 'owned-fault-stack.log'
        self.session = self.evidence / 'owned-fault-stack-session.json'
        self.cancel = self.evidence / 'owned-fault-stack-cancel'

    def _remember_observer(self, rows):
        if self.observer is None:
            return
        pid = self.observer.pid
        if not self.observer_owned and pid in rows:
            self.observer_owned[pid] = dict(rows[pid], pid=pid)
        elif (pid in self.observer_owned and pid in rows
              and self.observer_owned[pid]['start'] == rows[pid]['start']
              and self.observer.poll() is None):
            # xcrun may exec LLDB without changing PID/start. A still-live Popen
            # child cannot have been reaped/reused; retain its current full argv.
            self.observer_owned[pid] = dict(rows[pid], pid=pid)
        changed = True
        while changed:
            changed = False
            for child, row in rows.items():
                parent = row.get('parent')
                if (child not in self.observer_owned and parent in self.observer_owned
                        and same_process(self.observer_owned[parent], rows.get(parent))):
                    self.observer_owned[child] = dict(row, pid=child)
                    changed = True

    def _interrupt(self, reason):
        self.result.update(status='DIAGNOSTICALLY_INTERRUPTED', diagnosticallyInterrupted=True,
                           detail=str(reason)[:2048])
        try:
            rows = self.snapshot()
        except Exception as error:
            self.result['cleanupError'] = str(error)[:2048]
            self.result['remainingMatchedOwned'] = 'UNKNOWN: identity observation failed'
            return
        for identity in [self.identity, *reversed(list(self.observer_owned.values()))]:
            if identity and same_process(identity, rows.get(identity['pid'])):
                # The callback MUST freshly revalidate again before every cleanup signal.
                try:
                    self.cleanup(identity)
                except Exception as error:
                    self.result['cleanupError'] = str(error)[:2048]
        try:
            remaining = self.snapshot()
        except Exception as error:
            self.result['cleanupError'] = str(error)[:2048]
            self.result['remainingMatchedOwned'] = 'UNKNOWN: identity observation failed'
            return
        self.result['remainingMatchedOwned'] = [
            identity['pid'] for identity in [self.identity, *self.observer_owned.values()]
            if identity and same_process(identity, remaining.get(identity['pid']))]

    def _drain(self):
        try:
            with self.log.open('xb') as stream:
                retained = 0
                while True:
                    block = self.observer.stdout.read1(65536)
                    if not block:
                        break
                    available = max(0, FAULT_LOG_LIMIT - retained)
                    stream.write(block[:available])
                    retained += min(len(block), available)
                    if len(block) > available:
                        self.result['logTruncated'] = True
        except Exception as error:
            self.result['readerError'] = str(error)[:2048]

    def consider(self, owned):
        if self.attempted:
            return
        for pid, row in owned.items():
            identity = coverage_helper(pid, row, self.workspace)
            if identity is None:
                continue
            self.attempted, self.identity = True, identity
            if not same_process(identity, self.snapshot().get(pid)):
                self.result['status'] = 'identity-changed-or-exited'
                return
            if not self.budget.permits(FAULT_LOG_LIMIT):
                self.result['status'] = 'diagnostic-budget-refused'
                return
            self.budget.used += FAULT_LOG_LIMIT
            self.reserved = True
            identity_path = self.evidence / 'owned-fault-stack-identity.json'
            identity_path.write_text(json.dumps(identity) + '\n')
            script = ('script import sys,lldb; sys.path.insert(0, ' + repr(str(self.workspace / 'Tools/CI'))
                      + '); import crash_artifacts; crash_artifacts.run_owned_fault_session('
                      + 'lldb.debugger, ' + repr(str(identity_path)) + ', '
                      + repr(str(self.session)) + ', ' + repr(str(self.cancel)) + ')')
            try:
                self.observer = self.popen(
                    ['xcrun', 'lldb', '--no-lldbinit', '--batch', '-o', script],
                    cwd=self.workspace, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                self._remember_observer(self.snapshot())
                self.result['status'] = 'observing'
                self.reader = threading.Thread(target=self._drain)
                self.reader.start()
            except Exception as error:
                if self.observer is None:
                    self.result.update(status='observer-start-failed', diagnosticallyInterrupted=True,
                                       detail=str(error)[:2048])
                else:
                    self._interrupt(error)
            return

    def poll(self):
        if self.observer is None or self.result['status'] != 'observing':
            return
        self._remember_observer(self.snapshot())
        if 'readerError' in self.result:
            self._interrupt('Observer output reader failed.')
            return
        code = self.observer.poll()
        if code is None:
            if self.session.is_file() and self.session.stat().st_size <= 8192:
                session = json.loads(self.session.read_text())
                if session.get('pid') == self.identity['pid'] and not session.get('handedBack'):
                    self.result['session'] = session
                    self._interrupt('Debugger reports unresolved detach; guarded cleanup required.')
            return
        self.result['observerExitCode'] = code
        try:
            if not self.session.is_file() or self.session.stat().st_size > 8192:
                raise ValueError('Missing or oversized debugger session result.')
            session = json.loads(self.session.read_text())
            if session.get('pid') != self.identity['pid']:
                raise ValueError('Debugger session identity mismatch.')
            self.result['session'] = session
            if session.get('status') in ('observer-error', 'unexpected-stop', 'observer-cancelled'):
                raise ValueError('Debugger observation ended inconclusively.')
            if code != 0 or not session.get('handedBack'):
                raise ValueError('Debugger did not establish detached-or-exited target.')
            self.result['status'] = session['status']
        except Exception as error:
            self._interrupt(error)

    def finish(self):
        """Cooperate first; unresolved debugger lifetime is explicitly inconclusive."""
        if self.observer is not None:
            self.cancel.touch(exist_ok=True)
            try:
                self.observer.wait(timeout=5)
                self.poll()
            except subprocess.TimeoutExpired:
                self._interrupt('Observer cancellation timed out.')
            except Exception as error:
                self._interrupt(error)
            if self.reader is not None:
                self.reader.join(timeout=5)
                if self.reader.is_alive() or 'readerError' in self.result:
                    self._interrupt('Observer output did not close cleanly.')
        if self.reserved:
            self.budget.used -= FAULT_LOG_LIMIT
            self.budget.used += self.log.stat().st_size if self.log.exists() else 0
            self.reserved = False
        self.result['attempted'] = self.attempted
        if self.identity:
            self.result['identity'] = self.identity
        return self.result


def fault_text(value, limit):
    """Bound JSON-encoded diagnostic text within the existing session byte limit."""
    if value is None:
        return None
    text = str(value)
    while len(json.dumps(text).encode('utf-8')) > limit:
        text = text[:len(text) // 2]
    return text


def fault_memory_region(process, lldb, address):
    """Read VM bounds and permissions only, never target memory or expressions."""
    try:
        region = lldb.SBMemoryRegionInfo()
        error = process.GetMemoryRegionInfo(address, region)
        if error.Fail():
            return {'address': hex(address), 'status': 'unavailable', 'error': fault_text(error, 128)}
        return {'address': hex(address), 'status': 'available',
                'base': hex(region.GetRegionBase()), 'end': hex(region.GetRegionEnd()),
                'mapped': region.IsMapped(), 'readable': region.IsReadable(),
                'writable': region.IsWritable(), 'executable': region.IsExecutable(),
                'name': fault_text(region.GetName(), 128),
                'nameTruncated': fault_text(region.GetName(), 128) != region.GetName()}
    except Exception as error:
        return {'address': hex(address), 'status': 'unavailable', 'error': fault_text(error, 128)}


def fault_thread_details(thread, process, lldb):
    """Retain primitive fault facts separately from a bounded textual backtrace."""
    details = {}
    try:
        details.update(thread=thread.GetIndexID(), tid=thread.GetThreadID())
        description = thread.GetStopDescription(2048) or ''
        count = thread.GetStopReasonDataCount()
        details.update(stopReason=thread.GetStopReason(),
                       stopDescription=fault_text(description, 512),
                       stopDescriptionTruncated=fault_text(description, 512) != description,
                       stopReasonData=[hex(thread.GetStopReasonDataAtIndex(i))
                                       for i in range(min(count, 16))],
                       stopReasonDataTruncated=count > 16)
        frame = thread.GetFrameAtIndex(0)
        if not frame.IsValid():
            details['frameStatus'] = 'unavailable'
            return details
        sp = frame.GetSP()
        details.update(pc=hex(frame.GetPC()), sp=hex(sp), fp=hex(frame.GetFP()))
        if sp != lldb.LLDB_INVALID_ADDRESS:
            region = fault_memory_region(process, lldb, sp)
            details['stackRegion'] = region
            if region['status'] == 'available':
                base, end = int(region['base'], 16), int(region['end'], 16)
                if base > 0:
                    details['regionBelowStack'] = fault_memory_region(process, lldb, base - 1)
                if end < lldb.LLDB_INVALID_ADDRESS:
                    details['regionAboveStack'] = fault_memory_region(process, lldb, end)
        # Only a reported address is labelled as the fault address. Raw exception
        # words remain unclassified; an instruction-derived address is not substituted.
        address = re.search(r'\b(?:address|addr)\s*[=:]\s*(0x[0-9a-f]+)', description, re.I)
        if address:
            details['reportedFaultAddress'] = address.group(1)
            details['faultRegion'] = fault_memory_region(process, lldb, int(address.group(1), 16))
        else:
            details['faultAddressStatus'] = 'not-reported-in-stop-description'
    except Exception as error:
        details.update(metadataStatus='unavailable', metadataError=fault_text(error, 128))
    return details


def run_owned_fault_session(debugger, identity_path, session_path, cancel_path):
    """Runs inside LLDB only. No test launch, expression, core dump, kill or retry."""
    import lldb
    identity = json.loads(Path(identity_path).read_text())
    result = {'pid': identity['pid'], 'status': 'not-attached', 'handedBack': False}
    process = None
    attached = False
    try:
        raw = subprocess.check_output(
            ['ps', '-p', str(identity['pid']), '-o', 'lstart=,command=']).decode().strip()
        fields = raw.split(None, 5)
        row = {'start': ' '.join(fields[:5]), 'command': fields[5]} if len(fields) == 6 else None
        if not same_process(identity, row):
            result.update(status='identity-changed-or-exited', handedBack=True)
            return
        # Configure both automatic stop output and explicit backtrace headers before attach.
        # Default queue/activity/function-argument formatting can enter vendor type readers.
        for command in (
            r'settings set thread-format "thread #${thread.index}: tid=${thread.id}\n"',
            r'settings set thread-stop-format "thread #${thread.index}: tid=${thread.id}\n"',
            r'settings set frame-format "frame #${frame.index}: pc=${frame.pc}\n"',
        ):
            output = lldb.SBCommandReturnObject()
            debugger.GetCommandInterpreter().HandleCommand(command, output)
            if not output.Succeeded():
                raise RuntimeError('Unable to configure minimal fault format: '
                                   + (output.GetError() or '')[:512])
        debugger.SetAsync(False)
        target = debugger.CreateTarget(identity['arguments'][0])
        error = lldb.SBError()
        process = target.AttachToProcessWithID(debugger.GetListener(), identity['pid'], error)
        if error.Fail():
            result['status'] = 'attach-denied'
            result['error'] = str(error)[:2048]
            # A partial attachment still needs the explicit finally detach.
            result['handedBack'] = not process.IsValid()
            return
        attached = True
        debugger.SetAsync(True)
        signals = process.GetUnixSignals()
        for number in (4, 6, 10, 11):
            if not (signals.SetShouldStop(number, True)
                    and signals.SetShouldNotify(number, True)
                    and signals.SetShouldSuppress(number, False)):
                raise RuntimeError('Unable to install fatal-signal observation policy.')
        attached_stop = process.GetStopID()
        error = process.Continue()
        if error.Fail():
            raise RuntimeError(str(error))
        while not Path(cancel_path).exists():
            state = process.GetState()
            if state in (lldb.eStateExited, lldb.eStateDetached):
                result.update(status='target-exited', handedBack=True)
                return
            if (state in (lldb.eStateStopped, lldb.eStateCrashed)
                    and process.GetStopID() != attached_stop):
                fault_threads = [thread for thread in process
                                 if thread.GetStopReason() == lldb.eStopReasonException
                                 or (thread.GetStopReason() == lldb.eStopReasonSignal
                                     and thread.GetStopReasonDataAtIndex(0) in (4, 6, 10, 11))]
                fatal = bool(fault_threads)
                result['status'] = 'fault-captured' if fatal else 'unexpected-stop'
                if fatal:
                    # Full primary facts plus bounded thread IDs fit the unchanged8KiB session.
                    result['faultThreads'] = [fault_thread_details(fault_threads[0], process, lldb)]
                    result['faultThreadsTruncated'] = len(fault_threads) > 1
                    result['otherFaultThreads'] = [
                        {'thread': thread.GetIndexID(), 'tid': thread.GetThreadID()}
                        for thread in fault_threads[1:16]]
                    result['otherFaultThreadsTruncated'] = len(fault_threads) > 16
                    result['registerThreadSelected'] = process.SetSelectedThread(fault_threads[0])
                    print('fault-thread-facts ' + json.dumps(result['faultThreads']), flush=True)
                    commands = ('thread backtrace all -c 160', 'image list -o -u -f')
                    if result['registerThreadSelected']:
                        commands = ('register read', 'register read far esr') + commands
                    else:
                        result['registersStatus'] = 'unavailable: fault thread selection failed'
                    for command in commands:
                        output = lldb.SBCommandReturnObject()
                        debugger.GetCommandInterpreter().HandleCommand(command, output)
                        print(command, flush=True)
                        print((output.GetOutput() or '')[:FAULT_LOG_LIMIT], flush=True)
                        print((output.GetError() or '')[:4096], flush=True)
                return
            time.sleep(0.1)
        result['status'] = 'observer-cancelled'
    except subprocess.CalledProcessError:
        result.update(status='identity-changed-or-exited', handedBack=True)
    except Exception as error:
        result.update(status='observer-error', error=str(error)[:2048])
    finally:
        if process is not None and process.IsValid():
            if process.GetState() in (lldb.eStateExited, lldb.eStateDetached):
                result['handedBack'] = True
                if result['status'] == 'observer-cancelled':
                    result['status'] = 'target-exited'
            else:
                error = process.Detach(False)
                result['handedBack'] = (error.Success() and process.GetState()
                                        in (lldb.eStateExited, lldb.eStateDetached))
                if error.Fail():
                    result['detachError'] = str(error)[:2048]
        elif not attached and result['status'] == 'attach-denied':
            result['handedBack'] = True
        destination = Path(session_path)
        temporary = destination.with_suffix('.pending')
        temporary.write_text(json.dumps(result) + '\n')
        temporary.replace(destination)
        # Do not return into batch teardown with a live, unresolved attachment.
        # The parent reads this failure and revalidates identities before owned cleanup.
        while (process is not None and process.IsValid() and not result['handedBack']
               and process.GetState() not in (lldb.eStateExited, lldb.eStateDetached)):
            time.sleep(0.1)


def sha(path):
    """Hash a file without loading a large native image into memory."""
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def confined(path, parent):
    """Reject escaping or symbolic paths before reading an artifact."""
    parent = Path(parent).resolve(strict=True)
    path = Path(path)
    resolved = path.resolve(strict=True)
    resolved.relative_to(parent)
    relative = path.absolute().relative_to(parent)
    current = parent
    for part in relative.parts:
        current /= part
        if current.is_symlink():
            raise ValueError('Symbolic artifact paths are not retained.')
    return resolved


def arguments(record):
    """Parse only an already-owned process record, never infer ownership from its name."""
    try:
        return shlex.split(record['command'])
    except (KeyError, ValueError):
        return []


def observed_test_images(history, workspace):
    """Associate owned SwiftPM helper arguments with owned dsymutil outputs."""
    workspace = Path(workspace).resolve(strict=True)
    try:
        build = confined(workspace / '.build', workspace)
    except (OSError, ValueError) as error:
        return [{'status': 'refused-build-root', 'reason': str(error)}]
    result = []
    seen = set()
    for pid, records in history.items():
        for record in records:
            argv = arguments(record)
            if not argv or Path(argv[0]).name != 'swiftpm-testing-helper':
                continue
            item = {'pid': int(pid), 'start': record['start'], 'arguments': argv,
                    'helperExecutable': os.path.realpath(argv[0])}
            try:
                if argv.count('--test-bundle-path') != 1:
                    raise ValueError('A single observed test-bundle argument is required.')
                image = confined(argv[argv.index('--test-bundle-path') + 1], build)
                bundle = image.parent.parent.parent
                if (not image.is_file() or image.parent.name != 'MacOS'
                        or image.parent.parent.name != 'Contents' or bundle.suffix != '.xctest'
                        or image.name != bundle.stem):
                    raise ValueError('Not an observed native test-bundle image.')
                if str(image) in seen:
                    continue
                seen.add(str(image))
                item['image'] = str(image)
                for producers in history.values():
                    for producer in producers:
                        command = arguments(producer)
                        if (len(command) < 4 or Path(command[0]).name != 'dsymutil'
                                or command.count('-o') != 1):
                            continue
                        try:
                            source = confined(command[1], build)
                            target = confined(command[command.index('-o') + 1], build)
                        except (OSError, ValueError, IndexError):
                            continue
                        if source == image and target.is_dir() and target.suffix == '.dSYM':
                            item['dsym'] = str(target)
                item['status'] = 'observed-image'
            except (OSError, ValueError, IndexError) as error:
                item.update(status='refused-image', reason=str(error))
            result.append(item)
    return result


def image_uuids(path):
    """Read existing Mach-O metadata; this never executes the test image."""
    command = ['xcrun', 'dwarfdump', '--uuid', str(path)]
    try:
        output = subprocess.run(command, capture_output=True, text=True, timeout=10, check=False)
        uuids = {}
        for line in output.stdout.splitlines():
            match = re.fullmatch(r'UUID: ([0-9A-Fa-f-]{36}) \(([A-Za-z0-9_+-]+)\) .+', line)
            if match:
                if match[2] in uuids:
                    raise ValueError('Duplicate image architecture.')
                uuids[match[2]] = match[1].upper()
        return {'command': command, 'exitCode': output.returncode,
                'stdout': output.stdout[:4096], 'stderr': output.stderr[:4096],
                'uuids': uuids if output.returncode == 0 else {}}
    except (OSError, subprocess.TimeoutExpired, ValueError) as error:
        return {'command': command, 'uuids': {}, 'error': str(error)}


class ArtifactBudget:
    """Bound retained bytes explicitly; refusal never truncates an original."""
    def __init__(self, limit=ARTIFACT_LIMIT):
        self.limit = limit
        self.used = 0

    def permits(self, size):
        return 0 <= size <= self.limit - self.used


def retain_symbols(observed, record, destination, metadata, build, evidence, budget, uuid_reader):
    """Symbol retention runs only after every observed test image has its opportunity."""
    if 'dsym' not in observed:
        record['symbols'] = {'status': 'no-observed-dsym-producer'}
        return
    symbol_target = destination / Path(observed['dsym']).name
    try:
        symbols = confined(observed['dsym'], build)
        files = []
        for path in sorted(symbols.rglob('*')):
            resolved = confined(path, build)
            if resolved.is_file():
                files.append((path.relative_to(symbols), resolved))
        size = sum(path.stat().st_size for _, path in files)
        record['symbols'] = {'bytes': size}
        if not budget.permits(size):
            record['symbols'].update(status='refused-size-cap', limit=budget.limit)
            return
        symbol_metadata = uuid_reader(symbols)
        record['symbols']['UUID'] = symbol_metadata
        if not metadata.get('uuids') or metadata['uuids'] != symbol_metadata.get('uuids'):
            record['symbols']['status'] = 'missing-or-mismatched-uuid'
            return
        copied = {}
        for relative, original in files:
            target = symbol_target / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            digest = sha(original)
            shutil.copy2(original, target)
            if sha(target) != digest or sha(original) != digest:
                raise ValueError('Symbols changed during retention.')
            copied[str(relative)] = digest
        budget.used += size
        record['symbols'].update(status='retained-matching-dsym', files=copied,
                                 retained=str(symbol_target.relative_to(evidence)))
    except (OSError, ValueError) as error:
        if symbol_target.exists():
            shutil.rmtree(symbol_target)
        record['symbols'] = {'status': 'symbol-retention-error', 'reason': str(error)}


def retain_test_images(history, workspace, evidence, source, budget, uuid_reader=image_uuids):
    """Copy all observed images before spending any of their shared cap on symbols."""
    workspace = Path(workspace).resolve(strict=True)
    try:
        build = confined(workspace / '.build', workspace)
    except (OSError, ValueError) as error:
        return [{'status': 'refused-build-root', 'reason': str(error), 'source': source}]
    retained = []
    pending_symbols = []
    for index, observed in enumerate(observed_test_images(history, workspace)):
        record = dict(observed, source=source)
        retained.append(record)
        if observed['status'] != 'observed-image':
            continue
        destination = None
        try:
            image = confined(observed['image'], build)
            size = image.stat().st_size
            record['imageBytes'] = size
            if not budget.permits(size):
                record.update(status='refused-image-size-cap', limit=budget.limit)
                continue
            metadata = uuid_reader(image)
            record['imageUUID'] = metadata
            destination = Path(evidence) / 'native-images' / str(index)
            destination.mkdir(parents=True, exist_ok=False)
            target = destination / image.name
            digest = sha(image)
            shutil.copy2(image, target)
            if sha(target) != digest or sha(image) != digest:
                raise ValueError('Image changed during retention.')
            budget.used += size
            record.update(status='retained-image', imageSHA256=digest,
                          retainedImage=str(target.relative_to(evidence)))
            pending_symbols.append((observed, record, destination, metadata))
        except (OSError, ValueError) as error:
            if destination is not None and destination.exists():
                shutil.rmtree(destination)
            record.update(status='retention-error', reason=str(error))
    for observed, record, destination, metadata in pending_symbols:
        retain_symbols(observed, record, destination, metadata, build, evidence, budget, uuid_reader)
    return retained


def report_snapshot(roots):
    """Audit only the fixed report directories and known report extensions."""
    audit = []
    candidates = {}
    for base in map(Path, roots):
        entry = {'directory': str(base), 'exists': None, 'formats': {}}
        audit.append(entry)
        try:
            base.stat()
            entry['exists'] = True
            if base.is_symlink():
                entry['status'] = 'refused-symbolic-report-root'
                continue
        except FileNotFoundError:
            entry.update(exists=False, status='absent')
            continue
        except OSError as error:
            entry.update(status='unavailable', error=str(error))
            continue
        try:
            for path in sorted(base.iterdir()):
                if path.suffix not in REPORT_SUFFIXES:
                    continue
                entry['formats'][path.suffix] = entry['formats'].get(path.suffix, 0) + 1
                item = {'name': path.name, 'directory': str(base), 'format': path.suffix}
                candidates[str(path)] = item
                try:
                    actual = confined(path, base)
                    if not actual.is_file():
                        raise ValueError('Not a regular report file.')
                    stat = actual.stat()
                    item.update(sha256=sha(actual), bytes=stat.st_size,
                                modifiedNanoseconds=stat.st_mtime_ns)
                except (OSError, ValueError) as error:
                    item['error'] = str(error)
            entry['status'] = 'listed'
        except OSError as error:
            entry.update(status='unavailable', error=str(error))
    return {'directories': audit, 'candidates': candidates}


def launch_timestamp(value):
    """Accept only an explicitly zoned launch time, never substitute crash time."""
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


def report_identity(raw, suffix):
    """Read modern or legacy identity headers without guessing missing launch authority."""
    if suffix == '.crash':
        def header(name):
            value = re.search(r'^' + re.escape(name) + r':\s*(.+)$', raw, re.M)
            return value[1].strip() if value else None
        process = header('Process')
        pid = re.search(r'\[(\d+)\]\s*$', process or '')
        return {'pid': int(pid[1]) if pid else None, 'procPath': header('Path'),
                'procLaunch': header('Launch Time')}
    decoder = json.JSONDecoder()
    offset = 0
    documents = []
    try:
        while offset < len(raw):
            while offset < len(raw) and raw[offset].isspace():
                offset += 1
            if offset == len(raw):
                break
            value, offset = decoder.raw_decode(raw, offset)
            documents.append(value)
    except ValueError:
        return {}
    return next((value for value in documents if isinstance(value, dict)
                 and isinstance(value.get('pid'), int)
                 and isinstance(value.get('procPath'), str)), {})


def attributed_report(payload, history):
    """Join exact observed PID, launch second and executable path, including PID reuse."""
    pid = payload.get('pid')
    binary = payload.get('procPath')
    launch = launch_timestamp(payload.get('procLaunch'))
    if not isinstance(pid, int) or not isinstance(binary, str) or launch is None:
        return False
    for record in history.get(str(pid), history.get(pid, [])):
        argv = arguments(record)
        try:
            observed = datetime.strptime(record['start'], '%a %b %d %H:%M:%S %Y').timestamp()
        except (KeyError, ValueError):
            continue
        if (argv and abs(launch - observed) < 1.1
                and os.path.realpath(argv[0]) == os.path.realpath(binary)):
            return True
    return False


def helper_diagnostic_context(name, history, observed_images, evidence):
    """Scope candidate discovery to an owned retained cohort, never attribute a report."""
    if not re.fullmatch(r'\.?swiftpm-testing-helper-\d{4}-\d{2}-\d{2}-\d{6}\.(ips|crash)',
                        Path(name).name):
        return []
    contexts = []
    for image in observed_images:
        argv = image.get('arguments', [])
        pid = image.get('pid')
        if (image.get('status') != 'retained-image' or not image.get('retainedImage')
                or not argv or Path(argv[0]).name != 'swiftpm-testing-helper'
                or not isinstance(pid, int)):
            continue
        if not any(record.get('start') == image.get('start') and arguments(record) == argv
                   for record in history.get(str(pid), history.get(pid, []))):
            continue
        try:
            if not confined(Path(evidence) / image['retainedImage'], evidence).is_file():
                continue
        except (OSError, ValueError):
            continue
        contexts.append({key: image[key] for key in
                         ('pid', 'start', 'helperExecutable', 'image', 'retainedImage')})
    return contexts


def collect_reports(roots, baseline, history, evidence, budget, window=3.5, interval=0.5,
                    observed_images=()):
    """Drain report creation only; never rerun a command or alter its execution budget."""
    started = time.monotonic()
    records = {}
    retained = {}
    snapshots = []
    while True:
        current = report_snapshot(roots)
        snapshots.append({'elapsedSeconds': time.monotonic() - started,
                          'directories': current['directories']})
        for name, item in current['candidates'].items():
            digest = item.get('sha256')
            if digest is not None and digest == baseline['candidates'].get(name, {}).get('sha256'):
                continue
            saved = retained.get((name, digest))
            if saved is not None:
                detail = dict(saved)
                if not saved['matchedActualProcess'] and attributed_report(saved['identity'], history):
                    try:
                        previous_reference = saved['retained']
                        original = confined(Path(evidence) / previous_reference, evidence)
                        destination = Path(evidence) / 'matched-crashes'
                        destination.mkdir(exist_ok=True)
                        target = destination / original.name
                        if sha(original) != digest:
                            raise ValueError('Retained report changed before attribution.')
                        if target.exists():
                            target = confined(target, evidence)
                            if sha(target) != digest:
                                raise ValueError('Matched report target differs from original.')
                            if original != target:
                                original.unlink()
                        else:
                            original.replace(target)
                        # Both fixed roots can refer to the same verified retained file.
                        # Move every reference, but prove each record's identity independently.
                        current_reference = str(target.relative_to(evidence))
                        for reference in [*retained.values(), *records.values()]:
                            if reference.get('retained') != previous_reference:
                                continue
                            reference['retained'] = current_reference
                            if attributed_report(reference.get('identity', {}), history):
                                reference.update(
                                    matchedActualProcess=True, attribution='proved-pid-start-path',
                                    reason='later exact observed PID/start/path attribution',
                                    promotedFrom=previous_reference)
                        detail = dict(saved)
                    except (OSError, ValueError) as error:
                        detail['error'] = str(error)
                records[name] = detail
                continue
            detail = dict(item, matchedActualProcess=False)
            records[name] = detail
            if 'error' in item:
                continue
            try:
                original = confined(name, item['directory'])
                detail['snapshotBytes'] = item['bytes']
                detail['bytes'] = original.stat().st_size
                if not budget.permits(detail['bytes']):
                    detail['reason'] = 'artifact-size-cap'
                    continue
                with original.open('rb') as stream:
                    raw = stream.read(budget.limit - budget.used + 1)
                detail['bytes'] = len(raw)
                if not budget.permits(len(raw)):
                    detail['reason'] = 'artifact-size-cap'
                    continue
                digest = hashlib.sha256(raw).hexdigest()
                if digest != item['sha256']:
                    detail['reason'] = 'report-changing; retry within collection window'
                    continue
                identity = report_identity(raw.decode(errors='replace'), original.suffix)
                detail['identity'] = {key: identity.get(key) for key in ('pid', 'procPath', 'procLaunch')}
                matched = attributed_report(identity, history)
                initial = baseline['candidates'].get(name)
                changed = initial is None or initial.get('sha256') is not None
                context = (helper_diagnostic_context(name, history, observed_images, evidence)
                           if not matched and changed else [])
                if not matched and not context:
                    detail['reason'] = 'unproved PID/start/path attribution; metadata only'
                    continue
                folder = 'matched-crashes' if matched else 'unattributed-helper-diagnostics'
                destination = Path(evidence) / folder
                destination.mkdir(exist_ok=True)
                target = destination / (digest[:16] + '-' + original.name)
                if not target.exists():
                    target.write_bytes(raw)
                    budget.used += len(raw)
                if sha(target) != digest:
                    raise ValueError('Retained report differs from original bytes.')
                detail.update(matchedActualProcess=matched,
                              attribution='proved-pid-start-path' if matched else 'unproved',
                              retained=str(target.relative_to(evidence)))
                if not matched:
                    detail.update(reason='helper-family discovery only; process attribution unproved',
                                  observedContext=context)
                retained[(name, digest)] = dict(detail)
            except (OSError, ValueError) as error:
                detail['error'] = str(error)
        remaining = window - (time.monotonic() - started)
        if remaining <= 0:
            break
        time.sleep(min(interval, remaining))
    for name, record in records.items():
        versions = [{key: saved[key] for key in
                     ('sha256', 'bytes', 'retained', 'matchedActualProcess')}
                    for (source, digest), saved in retained.items()
                    if source == name and saved.get('retained') != record.get('retained')]
        if versions:
            record['retainedVersions'] = versions
    return list(records.values()), {'baselineDirectories': baseline['directories'],
                                   'observations': snapshots, 'budgetSeconds': window,
                                   'elapsedSeconds': time.monotonic() - started,
                                   'artifactLimitBytes': budget.limit,
                                   'retainedBytes': budget.used}
