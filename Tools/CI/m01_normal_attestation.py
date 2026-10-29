"""Qualify one preserved M01 normal run after reviewed bookkeeping-only changes."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

from sanitizer_checkpoints import digest

OLD_APPROVED = '7ebae4e5d03bc23bd8887e28f58e8d9c5da5576d'
OLD_TESTED = 'dbf67dfd340d099c59a972b3428e053a68a0d4d8'
OLD_RESULT_SHA = '55ef864b3a975a2bbc6495006eb3eeb9d23114d3413c682f179b8b7bbb5ef808'
OLD_POLICY_SHA = 'a6b67d2d3e8b3f627032ddf02b8fb9aa652f032ef6d54271ba437f5fb4836fe2'
OLD_KEY = '8ed0d1a57978b2aea093670f5d1d45bfe06e894b6ded58aed8087e12fd369e00'
OLD_ATTEMPT = 'de6785fa-862a-4473-bd05-3b4d45def876'
ALLOWED_PATHS = {
    '.gitignore', 'Makefile', 'Tools/CI/test_quality_phase_checkpoints.py',
    'Tools/CI/quality_phase_checkpoints.py', 'Tools/CI/m01_normal_attestation.py',
    'Tools/CI/test_m01_normal_attestation.py',
    'docs/ISSUE-m01-generated-profile.md', 'docs/PR-m01-generated-profile.md',
}


def sha_text(value):
    return hashlib.sha256(value.encode()).hexdigest()


def owned_file(path):
    """Require an immutable, physical file beneath owned non-writable directories."""
    for parent in path.parents:
        if parent.is_symlink() or parent.stat().st_uid not in (0, os.getuid()) or parent.stat().st_mode & 0o022:
            raise ValueError('Attestation trust directory is not owned and physical')
    if (path.is_symlink() or not path.is_file() or path.stat().st_uid != os.getuid()
            or path.stat().st_mode & 0o777 != 0o400):
        raise ValueError('Attestation trust file must be owned, physical and immutable')
    return json.loads(path.read_text())


def git(root, *arguments):
    return subprocess.check_output(['git', *arguments], cwd=root, stderr=subprocess.PIPE)


def blob_hash(root, revision, name):
    listing = git(root, 'ls-tree', '-z', revision, '--', name)
    if not listing:
        return None
    if not listing.startswith(b'100644 blob '):
        raise ValueError('Attested Git input must be a regular file')
    return hashlib.sha256(git(root, 'show', revision + ':' + name)).hexdigest()


def validate_binding(root, head, binding):
    """Bind the installed reviewer-approved manifest to exact committed delta bytes."""
    approved = binding['approved_head']
    if (binding['schema'] != 1 or binding['scope'] != 'M01-generated-profile-only'
            or not re.fullmatch(r'[0-9a-f]{40}', approved)
            or binding['old_approved_head'] != OLD_APPROVED):
        raise ValueError('Wrong one-off M01 authorization')
    tree = git(root, 'rev-parse', approved + '^{tree}').decode().strip()
    if (binding['approved_tree'] != tree
            or git(root, 'rev-parse', head + '^{tree}').decode().strip() != tree
            or git(root, 'rev-parse', 'HEAD').decode().strip() != head
            or git(root, 'status', '--porcelain').strip()):
        raise ValueError('Attestation requires the exact clean approved tree')
    changed = set(git(root, 'diff', '--name-only', '-z', OLD_APPROVED, approved).decode().strip('\0').split('\0'))
    deltas = binding['deltas']
    if not changed or changed != set(deltas) or not changed <= ALLOWED_PATHS:
        raise ValueError('Unreviewed source delta in M01 attestation')
    for name, pair in deltas.items():
        if (set(pair) != {'old_sha256', 'new_sha256'}
                or blob_hash(root, OLD_APPROVED, name) != pair['old_sha256']
                or blob_hash(root, approved, name) != pair['new_sha256']
                or digest(root / name) != pair['new_sha256']):
            raise ValueError('Reviewed M01 blob differs: ' + name)
    return deltas


def validate_identities(old, current, deltas, old_policy, new_policy, old_policy_path, new_policy_path):
    """Permit only the reviewed non-executed Python delta and exact-head authorization."""
    for key in set(old) | set(current):
        if key not in ('inputs', 'environment') and old.get(key) != current.get(key):
            raise ValueError('M01 execution identity differs: ' + key)
    old_inputs, new_inputs = old['inputs'], current['inputs']
    changed = {name for name in set(old_inputs) | set(new_inputs) if old_inputs.get(name) != new_inputs.get(name)}
    expected = {name for name in deltas if name.startswith('Tools/') or name == 'Makefile'}
    if changed != expected:
        raise ValueError('M01 executable/dependency inputs differ outside reviewed tools')
    for name in changed:
        if (old_inputs.get(name) != deltas[name]['old_sha256']
                or new_inputs.get(name) != deltas[name]['new_sha256']):
            raise ValueError('M01 executable input delta is not hash-bound')
    if (old_policy.get('approved_head') != OLD_APPROVED
            or new_policy.get('approved_head') == OLD_APPROVED
            or {k: v for k, v in old_policy.items() if k != 'approved_head'}
            != {k: v for k, v in new_policy.items() if k != 'approved_head'}):
        raise ValueError('Native authorization semantics changed')
    for identity, policy, path in ((old, old_policy, old_policy_path), (current, new_policy, new_policy_path)):
        if (identity['environment'].get('ELITE_NATIVE_APPROVED_HEAD') != sha_text(policy['approved_head'])
                or identity['environment'].get('ELITE_NATIVE_POLICY') != sha_text(str(path))):
            raise ValueError('Native authorization environment is not policy-bound')
    ignored = {'ELITE_NATIVE_APPROVED_HEAD', 'ELITE_NATIVE_POLICY'}
    if ({k: v for k, v in old['environment'].items() if k not in ignored}
            != {k: v for k, v in current['environment'].items() if k not in ignored}):
        raise ValueError('Runtime environment changed outside exact-head authorization')


def qualify(root, head, identity, environment, cache, successful_phase):
    """Return a separate attestation, never mutate or normalize the prior cache identity."""
    policy_name = environment.get('ELITE_NATIVE_POLICY')
    if identity['phase'] != 'normal' or not policy_name:
        return None
    policy_path = Path(policy_name)
    binding_path = policy_path.parent / 'm01-normal-attestation.json'
    if not binding_path.exists():
        return None
    binding = owned_file(binding_path)
    new_policy = owned_file(policy_path)
    if (new_policy['approved_head'] != binding['approved_head']
            or policy_path != Path.home() / 'Library/EliteNativeAuthorization' / binding['approved_head'] / 'policy.json'):
        raise ValueError('M01 authorization must use its exact host-owned policy path')
    from native_runner import validate
    validate(new_policy, environment)  # Recheck current event, actor, source, workflow, host and compiler.
    deltas = validate_binding(root, head, binding)
    old_policy_path = policy_path.parent.parent / OLD_APPROVED / 'policy.json'
    old_policy = owned_file(old_policy_path)
    if digest(old_policy_path) != OLD_POLICY_SHA:
        raise ValueError('Original M01 native policy changed')
    attempt = cache / 'phases' / OLD_KEY / OLD_ATTEMPT
    result_path = attempt / 'result.json'
    old_result = owned_file(result_path)
    if digest(result_path) != OLD_RESULT_SHA or old_result['tested_head'] != OLD_TESTED:
        raise ValueError('Original M01 execution receipt changed')
    old_identity = old_result['identity']
    if (git(root, 'rev-parse', OLD_TESTED + '^{tree}') != git(root, 'rev-parse', OLD_APPROVED + '^{tree}')
            or successful_phase(attempt, old_identity) != old_result):
        raise ValueError('Original M01 normal outputs no longer qualify')
    validate_identities(old_identity, identity, deltas, old_policy, new_policy, old_policy_path, policy_path)
    attestation = {
        'status': 'attested-from-prior-execution', 'scope': 'normal-coverage-only',
        'tested_head': OLD_TESTED, 'original_approved_head': OLD_APPROVED,
        'qualified_head': head, 'qualified_approved_head': binding['approved_head'],
        'new_test_execution_seconds': 0, 'original_test_wall_seconds': old_result['test_wall_seconds'],
        'original_attempt': str(attempt), 'original_result_sha256': OLD_RESULT_SHA,
        'original_identity': old_identity, 'current_identity': identity,
        'reviewed_deltas': deltas, 'host_binding_sha256': digest(binding_path),
        'old_policy_sha256': digest(old_policy_path), 'new_policy_sha256': digest(policy_path),
        'old_policy': old_policy, 'new_policy': new_policy,
        'old_policy_path': str(old_policy_path), 'new_policy_path': str(policy_path),
        'outputs': old_result['outputs'], 'validation': old_result['validation'],
        'limitation': 'No new normal execution. Thread/address sanitizers and leaks remain independent gates.',
    }
    return attempt, old_result, attestation
