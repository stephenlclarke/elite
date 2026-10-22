"""Observe the existing unit child and retain failure evidence; never launch a test."""
from pathlib import Path
import json
import shlex
import shutil
import subprocess
import threading

from crash_artifacts import (ArtifactBudget, collect_reports, report_snapshot,
                             retain_test_images, same_process)


def snapshot():
    """Read process identities, including full start second and command, without attaching."""
    raw = subprocess.check_output(
        ['ps', '-axo', 'pid=,ppid=,lstart=,command='], text=True, timeout=2)
    rows = {}
    for line in raw.splitlines():
        fields = line.split(None, 7)
        if len(fields) == 8:
            rows[int(fields[0])] = {'parent': int(fields[1]),
                                   'start': ' '.join(fields[2:7]), 'command': fields[7]}
    return rows


def observe_descendants(rows, root, known, history):
    """Only currently identity-matched owned parents may confer child ownership."""
    selected = {pid for pid, record in known.items()
                if same_process(record, rows.get(pid))}
    if root not in known and root in rows:
        selected.add(root)
    while True:
        children = {pid for pid, row in rows.items() if row['parent'] in selected}
        if children <= selected:
            break
        selected |= children
    for pid in selected:
        row = rows[pid]
        if pid not in known or not same_process(known[pid], row):
            history.setdefault(pid, []).append(dict(row))
        known[pid] = dict(row)


class IsolatedCrashEvidence:
    """Read-only process observation; no debugger, signalling, retry or changed test budget."""
    def __init__(self, workspace, evidence, roots=None, read_snapshot=snapshot):
        self.workspace, self.evidence = Path(workspace), Path(evidence)
        resolved = self.evidence.resolve()
        if (self.evidence.is_symlink() or resolved == self.workspace.resolve()
                or not resolved.is_relative_to(self.workspace.resolve())):
            raise ValueError('Failure evidence must be a confined owned output directory.')
        if self.evidence.exists():
            shutil.rmtree(self.evidence)  # A prior run's report must never enter this run's artifact.
        self.roots = roots if roots is not None else [
            Path.home() / 'Library/Logs/DiagnosticReports',
            Path('/Library/Logs/DiagnosticReports')]
        self.baseline = report_snapshot(self.roots)
        self.read_snapshot = read_snapshot
        self.known, self.history, self.errors = {}, {}, []
        self.stop = threading.Event()
        self.watcher = None

    def observe(self, rows, root):
        observe_descendants(rows, root, self.known, self.history)
        # Compiler command lines can be enormous. Keep only live ancestry and the actual
        # test/helper/symbol identities needed by the existing failure collector.
        for pid in list(self.history):
            kept = []
            for record in self.history[pid]:
                lexer = shlex.shlex(record['command'], posix=True)
                lexer.whitespace_split = True
                executable = Path(next(lexer, '')).name
                if pid == root or executable in {
                        'swiftpm-testing-helper', 'ElitePackageTests', 'dsymutil'}:
                    kept.append(record)
            if kept:
                self.history[pid] = kept
            else:
                del self.history[pid]
        self.known = {pid: record for pid, record in self.known.items()
                      if pid == root or same_process(record, rows.get(pid))}

    def start(self, process):
        def observe():
            try:
                # The live Popen root is the sole initial authority; retain descendants by identity.
                if process.poll() is None:
                    self.observe(self.read_snapshot(), process.pid)
                while not self.stop.wait(0.1):
                    rows = self.read_snapshot()
                    # An exited/reused root PID must never become a new initial authority.
                    if process.pid not in self.known:
                        if process.poll() is not None:
                            continue
                    self.observe(rows, process.pid)
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                self.errors.append({'type': type(error).__name__, 'detail': str(error)[:2048]})
        self.watcher = threading.Thread(target=observe, daemon=True)
        self.watcher.start()

    def finish(self, source, failed):
        self.stop.set()
        if self.watcher:
            self.watcher.join(timeout=5)
        result = {'failureOnly': True, 'errors': list(self.errors),
                  'observerAlive': self.watcher.is_alive() if self.watcher else False}
        if not failed:
            return result
        self.evidence.mkdir(parents=True, exist_ok=True)
        def write(name, value):
            (self.evidence / name).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
        write('observed-processes.json', self.history)
        try:
            if result['observerAlive']:
                raise ValueError('Process observer did not finish; attribution unavailable.')
            budget = ArtifactBudget()
            images = retain_test_images(self.history, self.workspace, self.evidence, source, budget)
            records, audit = collect_reports(self.roots, self.baseline, self.history,
                                            self.evidence, budget)
            # Retain full reports only after exact observed PID/start/executable attribution.
            # The collector's unrelated candidates remain metadata internally, never uploaded.
            records = [record for record in records if record.get('matchedActualProcess')]
            write('native-images.json', images)
            write('crash-originals.json', records)
            write('report-discovery.json', audit)
            result['reports'] = len(records)
            result['matchedReports'] = sum(record.get('matchedActualProcess', False)
                                           for record in records)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            result['captureError'] = {'type': type(error).__name__, 'detail': str(error)[:2048]}
        write('capture.json', result)
        return result
