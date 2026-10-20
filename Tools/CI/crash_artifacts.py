"""Retain confined failure evidence with explicit process-attribution boundaries."""
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import time

ARTIFACT_LIMIT = 512 * 1024 * 1024
REPORT_SUFFIXES = {'.ips', '.crash'}


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
                        original = confined(Path(evidence) / saved['retained'], evidence)
                        destination = Path(evidence) / 'matched-crashes'
                        destination.mkdir(exist_ok=True)
                        target = destination / original.name
                        if sha(original) != digest:
                            raise ValueError('Retained report changed before attribution.')
                        if target.exists():
                            target = confined(target, evidence)
                            if sha(target) != digest:
                                raise ValueError('Matched report target differs from original.')
                            original.unlink()
                        else:
                            original.replace(target)
                        detail.update(matchedActualProcess=True, attribution='proved-pid-start-path',
                                      reason='later exact observed PID/start/path attribution',
                                      promotedFrom=saved['retained'],
                                      retained=str(target.relative_to(evidence)))
                        retained[(name, digest)] = detail
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
