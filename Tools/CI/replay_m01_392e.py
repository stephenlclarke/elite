"""One unmerged diagnostic replay of the exact retained eed9 coverage image; never build."""
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import runpy
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'reports/m01-retained-replay'
SOURCE = 'eed9dae5b7a1fae098a85a57a996d555f55f3b2b'
IMAGE_SHA = '9081c826d5dc55d78dc649e8b99d3400ffb10406c1db1342f85cc3fce0785059'
UUID = 'B50DBAA9-2482-375C-8867-1037424B648B'
FILTER_SHA = '48afd0a198777bcaed1a18350fde67792d5f835d25c33ec1fb2e3c1fc469dd6e'
DEVELOPER = Path('/Applications/Xcode_16.4.app/Contents/Developer')
HELPER = DEVELOPER / 'Toolchains/XcodeDefault.xctoolchain/usr/libexec/swift/pm/swiftpm-testing-helper'
IMAGE = ROOT / '.build/arm64-apple-macosx/debug/ElitePackageTests.xctest/Contents/MacOS/ElitePackageTests'


def digest(path):
    checksum = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            checksum.update(block)
    return checksum.hexdigest()


def write(name, value):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(json.dumps(value, indent=2) + '\n')


def checked(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def runtime_closure(frameworks, libraries):
    """Resolve this pinned image/helper's installed non-system dependencies before launch."""
    pending, seen, records = [IMAGE, HELPER], set(), []
    while pending:
        image = pending.pop().resolve()
        if image in seen:
            continue
        seen.add(image)
        load_commands = checked('xcrun', 'otool', '-l', str(image))
        rpaths = re.findall(r'cmd LC_RPATH\s+cmdsize \d+\s+path (.+?) \(offset', load_commands)
        def expand(value):
            return Path(value.replace('@loader_path', str(image.parent))
                        .replace('@executable_path', str(HELPER.parent)))
        for line in checked('xcrun', 'otool', '-L', str(image)).splitlines():
            match = re.match(r'\s+(.+?) \(compatibility', line)
            if not match:
                continue
            dependency = match[1]
            if dependency.startswith(('/usr/lib/', '/System/Library/')):
                continue  # System images may reside only in the dyld shared cache.
            if dependency.startswith('@rpath/'):
                relative = dependency[len('@rpath/'):]
                choices = [p / relative for p in libraries + frameworks]
                choices += [expand(p) / relative for p in rpaths]
            else:
                choices = [expand(dependency)]
            found = next((p.resolve() for p in choices if p.is_file()), None)
            require(found is not None, 'Installed runtime dependency unresolved: ' + dependency)
            records.append({'image': str(image), 'dependency': dependency, 'resolved': str(found)})
            if found != image:
                pending.append(found)
    write('runtime-dependencies.json', records)


def prepare():
    """Fail closed before launch; preserve the original artifact and source resource bytes."""
    require(ROOT == Path('/Users/runner/work/elite/elite'), 'Original baked resource path differs.')
    require(platform.machine() == 'arm64', 'Original arm64 runner required.')
    require(checked('sw_vers', '-productVersion') == '15.7.9'
            and checked('sw_vers', '-buildVersion') == '24G830', 'Original macOS runtime differs.')
    require(Path(checked('xcode-select', '-p')) == DEVELOPER, 'Selected Xcode differs.')
    version = checked('xcrun', 'swift', '--version')
    require(version.splitlines()[0] == 'Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)',
            'Original Swift runtime/toolchain differs.')
    require(HELPER.is_file(), 'Original testing helper is unavailable.')
    subprocess.run(['git', 'diff', '--exit-code', SOURCE, '--', 'Sources', 'Tests', 'Package.swift',
                    'Package.resolved', 'Tools/CI/isolated_units.py', 'Tools/CI/crash_artifacts.py',
                    'Tools/CI/isolated_crash_evidence.py'], cwd=ROOT, check=True)
    upstream = json.loads((OUT / 'upstream-run.json').read_text())
    require(upstream['id'] == 39845001834 and upstream['head_sha'] == SOURCE
            and upstream['conclusion'] == 'failure', 'Wrong upstream run.')
    original = ROOT / '.build/m01-replay-original'
    result = json.loads((original / 'result.json').read_text())
    require(result['commit'] == SOURCE and result['status'] == 'failed', 'Wrong original result.')
    units = runpy.run_path(str(ROOT / 'Tools/CI/isolated_units.py'))
    expression = result['command'][result['command'].index('--filter') + 1]
    require(expression == units['selection']() and sum(map(len, units['METHODS'].values())) == 346
            and hashlib.sha256(expression.encode()).hexdigest() == FILTER_SHA,
            'Original 346-method selection differs.')
    records = json.loads((original / 'failure-evidence/native-images.json').read_text())
    require(len(records) == 1, 'Expected exactly one retained test image.')
    record = records[0]
    require(record['source'] == SOURCE and record['status'] == 'retained-image'
            and record['imageSHA256'] == IMAGE_SHA, 'Wrong retained image identity.')
    retained = original / 'failure-evidence/native-images/0/ElitePackageTests'
    symbols = retained.with_name('ElitePackageTests.dSYM')
    require(not retained.is_symlink() and digest(retained) == IMAGE_SHA, 'Image hash differs.')
    require(record['symbols']['status'] == 'retained-matching-dsym', 'Matching symbols unavailable.')
    for relative, expected in record['symbols']['files'].items():
        item = symbols / relative
        require(item.resolve().is_relative_to(symbols.resolve()) and not item.is_symlink()
                and digest(item) == expected, 'Symbol file differs.')
    for item in (retained, symbols):
        require(re.findall(r'UUID: ([A-F0-9-]+) \(arm64\)', checked('xcrun', 'dwarfdump', '--uuid', str(item)))
                == [UUID], 'Original image/symbol UUID differs.')
    original_xml = ROOT / 'reports/isolated-units/tests-swift-testing.xml'
    arguments = ['--test-bundle-path', str(IMAGE), '--jobs', '3', '--enable-code-coverage',
                 '--filter', expression, '--xunit-output', str(original_xml), str(IMAGE),
                 '--testing-library', 'swift-testing']
    observed = [str(HELPER), *arguments]
    # The old process observer's shlex parser removed regex backslashes. Restore ONLY
    # that field from result.json's exact original command, independently joined to source.
    observed[7] = expression.replace('\\', '')
    require(record['arguments'] == observed, 'Original helper arguments differ beyond known escaping.')
    require(not IMAGE.exists() and not original_xml.exists(), 'Refuse stale staged execution output.')
    original_xml.parent.mkdir(parents=True, exist_ok=True)
    IMAGE.parent.mkdir(parents=True)
    shutil.copy2(retained, IMAGE)
    shutil.copytree(symbols, IMAGE.with_name('ElitePackageTests.dSYM'))
    require(digest(IMAGE) == IMAGE_SHA, 'Staged image differs.')
    copied = runpy.run_path(str(ROOT / 'Tools/distribution/package_macos.py'))['COPIED_RESOURCE_DIRECTORIES']
    package = (ROOT / 'Package.swift').read_text()
    require(set(re.findall(r'\.copy\("Resources/([^"]+)"\)', package)) == set(copied),
            'Copied-resource mapping differs from the existing packager.')
    bundle = IMAGE.parents[3] / 'Elite_EliteCore.bundle'
    require(not bundle.exists(), 'Refuse an existing resource bundle.')
    inventory = {}
    for source in sorted((ROOT / 'Sources/EliteCore/Resources').rglob('*')):
        require(not source.is_symlink(), 'Resource symlinks are not supported for this replay.')
        if not source.is_file():
            continue
        relative = source.relative_to(ROOT / 'Sources/EliteCore/Resources')
        destination = bundle / (relative if relative.parts[0] in copied else source.name)
        require(not destination.exists(), 'Resource flattening collision.')
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        require(digest(destination) == digest(source), 'Staged resource bytes differ.')
        inventory[str(relative)] = {'destination': str(destination.relative_to(bundle)),
                                    'sha256': digest(source)}
    # Only standard generated bundle metadata is synthesized; all product resource bytes
    # use the existing packager's copied/processed layout and remain exact source bytes.
    (bundle / 'Info.plist').write_bytes(plistlib.dumps({'CFBundlePackageType': 'BNDL',
        'CFBundleName': 'Elite_EliteCore', 'CFBundleDevelopmentRegion': 'en'}))
    frameworks = [DEVELOPER / 'Platforms/MacOSX.platform/Developer/Library/Frameworks',
                  DEVELOPER / 'Platforms/MacOSX.platform/Developer/Library/PrivateFrameworks',
                  DEVELOPER.parent / 'SharedFrameworks']
    libraries = [DEVELOPER / 'Platforms/MacOSX.platform/Developer/usr/lib', DEVELOPER / 'usr/lib']
    require(all(p.is_dir() for p in frameworks + libraries), 'Installed test runtime paths unavailable.')
    require((frameworks[0] / 'Testing.framework/Versions/A/Testing').is_file(), 'Original Testing unavailable.')
    runtime_closure(frameworks, libraries)
    write('resources.json', inventory)
    write('launch.json', {'source': SOURCE, 'diagnosticCommit': checked('git', 'rev-parse', 'HEAD'),
        'diagnosticOnly': True, 'originalRun': 39845001834, 'originalMethods': 346,
        'imageSHA256': IMAGE_SHA, 'imageUUID': UUID, 'swiftVersion': version,
        'arguments': arguments, 'filterSHA256': FILTER_SHA, 'helper': str(HELPER),
        'coverageInstrumentedImage': True, 'parallelism': 3, 'executionLimitSeconds': 180,
        'environment': {'DYLD_FRAMEWORK_PATH': ':'.join(map(str, frameworks)),
                        'DYLD_LIBRARY_PATH': ':'.join(map(str, libraries)),
                        'SWIFT_BACKTRACE': units['runtime_child_environment']({})['SWIFT_BACKTRACE'],
                        'LLVM_PROFILE_FILE': str(OUT / 'replay-%p.profraw')},
        'filterRestoration': 'Original result.command filter; observer metadata had stripped backslashes.',
        'resourceReconstruction': 'Existing packager byte layout plus generated bundle metadata.'})
    write('result.json', {'status': 'prepared-not-launched', 'diagnosticOnly': True, 'launchCount': 0})


def capture(debugger):
    """Launch the pinned image once; stop at its actual fault, never retry or qualify."""
    import lldb
    plan = json.loads((OUT / 'launch.json').read_text())
    result = {'source': SOURCE, 'diagnosticOnly': True, 'launchCount': 0, 'status': 'not-launched'}
    process = None
    try:
        require(plan['source'] == SOURCE and digest(IMAGE) == IMAGE_SHA, 'Prepared image changed.')
        require(json.loads((OUT / 'result.json').read_text())['launchCount'] == 0, 'Replay already attempted.')
        for command in (r'settings set thread-format "thread #${thread.index}: tid=${thread.id}\n"',
                        r'settings set thread-stop-format "thread #${thread.index}: tid=${thread.id}\n"',
                        r'settings set frame-format "frame #${frame.index}: pc=${frame.pc}\n"'):
            response = lldb.SBCommandReturnObject()
            debugger.GetCommandInterpreter().HandleCommand(command, response)
            require(response.Succeeded(), response.GetError() or 'Minimal format setup failed.')
        target = debugger.CreateTarget(plan['helper'])
        launch = lldb.SBLaunchInfo(plan['arguments'])
        launch.SetWorkingDirectory(str(ROOT))
        environment = dict(os.environ, **plan['environment'])
        launch.SetEnvironmentEntries([key + '=' + value for key, value in environment.items()], True)
        launch.AddOpenFileAction(1, str(OUT / 'stdout.log'), False, True)
        launch.AddOpenFileAction(2, str(OUT / 'stderr.log'), False, True)
        launch.SetLaunchFlags(lldb.eLaunchFlagDebug | lldb.eLaunchFlagStopAtEntry)
        debugger.SetAsync(False)
        error = lldb.SBError()
        started = time.monotonic()
        result['launchCount'] = 1
        write('result.json', dict(result, status='launch-attempted'))
        process = target.Launch(launch, error)
        require(not error.Fail(), str(error))
        result['pid'] = process.GetProcessID()
        signals = process.GetUnixSignals()
        for number in (4, 6, 10, 11):
            require(signals.SetShouldStop(number, True) and signals.SetShouldNotify(number, True)
                    and signals.SetShouldSuppress(number, False), 'Fatal-signal policy unavailable.')
        initial_stop = process.GetStopID()
        debugger.SetAsync(True)
        error = process.Continue()
        require(not error.Fail(), str(error))
        while time.monotonic() - started < 180:
            state = process.GetState()
            if state == lldb.eStateExited:
                result.update(status='diagnostic-target-exited', exitCode=process.GetExitStatus())
                break
            if state in (lldb.eStateStopped, lldb.eStateCrashed) and process.GetStopID() != initial_stop:
                result['status'] = 'diagnostic-stop-captured'
                result['threads'] = [{'id': t.GetThreadID(), 'reason': t.GetStopReason(),
                    'data': [t.GetStopReasonDataAtIndex(i) for i in range(t.GetStopReasonDataCount())],
                    'registers': {name: t.GetFrameAtIndex(0).FindRegister(name).GetValue()
                                  for name in ['pc', 'lr', 'sp', 'fp'] + ['x' + str(i) for i in range(29)]},
                    'frames': [{'pc': hex(f.GetPC()), 'function': f.GetFunctionName(),
                                'file': str(f.GetLineEntry().GetFileSpec()),
                                'line': f.GetLineEntry().GetLine()} for f in list(t)[:64]]}
                    for t in process]
                for command in ('thread backtrace all -c 64', 'register read', 'image list -u -f'):
                    response = lldb.SBCommandReturnObject()
                    debugger.GetCommandInterpreter().HandleCommand(command, response)
                    print(command, flush=True)
                    print((response.GetOutput() or '')[:1048576], flush=True)
                    print((response.GetError() or '')[:4096], flush=True)
                break
            if any(p.stat().st_size > 2097152 for p in (OUT / 'stdout.log', OUT / 'stderr.log')):
                result['status'] = 'DIAGNOSTICALLY_INTERRUPTED_OUTPUT_BOUND'
                break
            time.sleep(0.1)
        else:
            result['status'] = 'DIAGNOSTICALLY_INTERRUPTED_TIMEOUT'
        result['elapsedSeconds'] = round(time.monotonic() - started, 3)
    except Exception as error:
        result.update(status='diagnostic-error', error=str(error)[:4096])
    finally:
        if process and process.IsValid() and process.GetState() not in (lldb.eStateExited, lldb.eStateDetached):
            result['ownedCleanup'] = str(process.Kill())
        if process and process.IsValid():
            result['finalState'] = process.GetState()
        report = ROOT / 'reports/isolated-units/tests-swift-testing.xml'
        if report.is_file() and not report.is_symlink():
            shutil.copy2(report, OUT / 'diagnostic-tests.xml')
        write('result.json', result)
        print(json.dumps(result), flush=True)


if __name__ == '__main__':
    if sys.argv[1:] == ['prepare']:
        try:
            prepare()
        except Exception as error:
            write('result.json', {'status': 'preflight-refused', 'diagnosticOnly': True,
                                 'launchCount': 0, 'error': str(error)[:4096]})
            raise
    elif sys.argv[1:] == ['outcome']:
        result = json.loads((OUT / 'result.json').read_text())
        print(json.dumps(result))
        # Even a complete diagnostic pass is not a required-check qualification.
        sys.exit(0 if result['status'] == 'diagnostic-target-exited' and result.get('exitCode') == 0 else 1)
    else:
        raise SystemExit('Only prepare and outcome are supported.')
