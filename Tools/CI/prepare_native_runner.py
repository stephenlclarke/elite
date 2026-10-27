"""Prepare an ephemeral physical runner with an immutable, host-owned exact-head hook."""

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import tarfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
HOME_ROOT = Path.home() / "Library/EliteNativeCI"
RUNNER = HOME_ROOT / "native-runner"
AUTHORIZATION_ROOT = Path.home() / "Library/EliteNativeAuthorization"
DEVELOPER = "/Applications/Xcode.app/Contents/Developer"


def output(*args: str, environment: dict) -> str:
    """Capture non-secret tool identities without shell interpretation."""
    return subprocess.check_output(args, cwd=ROOT, env=environment, text=True,
                                   stderr=subprocess.PIPE).strip()


def ensure_owned_directory(path: Path) -> None:
    """Create private trust directories and reject writable or substituted parents."""
    if path.is_symlink():
        raise ValueError("Runner trust directory must be physical.")
    if not path.exists():
        ensure_owned_directory(path.parent)
        path.mkdir(mode=0o700)
    if (not path.is_dir() or path.stat().st_uid != os.getuid()
            or path.stat().st_mode & 0o022):
        raise ValueError("Runner trust directory must be owned and not publicly writable.")


def prepare(approved: str, archive: Path, archive_hash: str, reviewed_policy=None, policy_sha256=None, registered=False) -> Path:
    """Install only a verified runner archive and reviewed guard into dedicated owned paths."""
    if not re.fullmatch(r"[0-9a-f]{40}", approved):
        raise ValueError("Invalid approved source identity.")
    if not re.fullmatch(r"[0-9a-f]{64}", archive_hash):
        raise ValueError("A verified runner archive digest is required.")
    environment = dict(os.environ, DEVELOPER_DIR=DEVELOPER)
    if output("git", "rev-parse", "HEAD", environment=environment) != approved:
        raise ValueError("Prepare from the exact approved checkout.")
    if output("git", "status", "--porcelain", environment=environment):
        raise ValueError("Prepare from a clean committed checkout.")
    guard = ROOT / "Tools/CI/native_runner.py"
    archive = archive.resolve(strict=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != archive_hash:
        raise ValueError("Runner archive digest differs from the verified release asset.")
    authorization = AUTHORIZATION_ROOT / approved
    if any(character.isspace() for character in str(authorization)):
        raise ValueError("The runner dispatches its hook through a shell; its path must not contain whitespace.")
    if any(character.isspace() for character in str(RUNNER)):
        raise ValueError("The runner dispatches temporary scripts through a shell; its root must not contain whitespace.")
    guard_copy = authorization / "guard.py"
    policy = authorization / "policy.json"
    hook = authorization / "job-started.sh"
    guard_bytes = guard.read_bytes()
    expected_policy = {
        "approved_head": approved, "runner_root": str(RUNNER), "developer_dir": DEVELOPER,
        "swift": output("swift", "--version", environment=environment),
        "sdk": output("xcrun", "--sdk", "macosx", "--show-sdk-version", environment=environment),
        "guard_sha256": hashlib.sha256(guard_bytes).hexdigest(),
        "runner_archive_sha256": archive_hash,
    }
    helpers = []
    if reviewed_policy is not None:
        if guard.is_symlink():
            raise ValueError("Reviewed guard source must be a physical file.")
        expected_policy = reviewed_recoverable_policy(reviewed_policy, policy_sha256, expected_policy)
        authorization = authorization / ("recoverable-" + policy_sha256)
        guard_copy, policy, hook = (authorization / name for name in ("native_runner.py", "policy.json", "job-started.sh"))
        helpers = [(authorization / name, (ROOT / "Tools/CI" / name).read_bytes(), 0o400)
                   for name in expected_policy["recoverable_activation"]["guard_files"]]
    policy_bytes = (json.dumps(expected_policy, indent=2) + "\n").encode()
    hook_bytes = ("#!/bin/bash\nset -euo pipefail\nexec /usr/bin/python3 "
                  + shlex.quote(str(guard_copy)) + " --policy " + shlex.quote(str(policy)) + "\n").encode()
    if reviewed_policy is not None:
        hook_bytes = session_hook(expected_policy, policy, guard_copy)
    ensure_owned_directory(HOME_ROOT)
    ensure_owned_directory(authorization.parent)
    if RUNNER.is_symlink():
        raise ValueError("Runner directory must be physical.")
    if RUNNER.exists():
        if (not RUNNER.is_dir() or RUNNER.stat().st_uid != os.getuid()
                or RUNNER.stat().st_mode & 0o022):
            raise ValueError("Existing runner directory is not owned by this setup.")
        marker = RUNNER / ".elite-native-owner"
        if marker.is_symlink() or not marker.is_file() or marker.read_text() != "stephenlclarke/elite\n":
            raise ValueError("Existing runner ownership marker differs.")
        if (RUNNER / ".runner").exists() or (RUNNER / ".runner").is_symlink():
            if not (reviewed_policy is not None and registered):
                raise ValueError("The previous runner registration is still active.")
            require_registration(expected_policy)
    else:
        RUNNER.mkdir(mode=0o700)
        with tarfile.open(archive) as source:
            source.extractall(RUNNER, filter="data")
        (RUNNER / ".elite-native-owner").write_text("stephenlclarke/elite\n")
    verify_installed_archive(RUNNER, archive)
    installation = RUNNER / ".elite-native-installation.json"
    installation_bytes = (json.dumps({"archive_sha256": archive_hash}) + "\n").encode()
    if installation.is_symlink():
        raise ValueError("Installation provenance must be physical.")
    if installation.exists():
        if (not installation.is_file() or installation.stat().st_uid != os.getuid()
                or installation.stat().st_mode & 0o777 != 0o400
                or installation.read_bytes() != installation_bytes):
            raise ValueError("Existing immutable installation provenance differs.")
    else:
        with installation.open("xb") as destination:
            destination.write(installation_bytes)
        installation.chmod(0o400)
    files = [(guard_copy, guard_bytes, 0o500), (policy, policy_bytes, 0o400),
             (hook, hook_bytes, 0o500), *helpers]
    if authorization.is_symlink():
        raise ValueError("Authorization directory must be physical.")
    if authorization.exists():
        ensure_owned_directory(authorization)
        for path, expected, mode in files:
            if (path.is_symlink() or not path.is_file() or path.stat().st_uid != os.getuid()
                    or path.stat().st_mode & 0o777 != mode or path.read_bytes() != expected):
                raise ValueError("Existing immutable authorization differs; preserving it.")
    else:
        ensure_owned_directory(authorization.parent)
        authorization.mkdir(parents=True, exist_ok=False, mode=0o700)
        for path, data, mode in files:
            with path.open("xb") as destination:
                destination.write(data)
                destination.flush()
                os.fsync(destination.fileno())
            path.chmod(mode)
    if (RUNNER / ".env").is_symlink():
        raise ValueError("Runner environment file is not physical.")
    environment_bytes = "ACTIONS_RUNNER_HOOK_JOB_STARTED=" + str(hook) + "\nDEVELOPER_DIR=" + DEVELOPER + "\n"
    if registered and (RUNNER / ".env").read_text() != environment_bytes:
        raise ValueError("An active registration uses a different hook; preserving it.")
    (RUNNER / ".env").write_text(environment_bytes)
    (RUNNER / ".env").chmod(0o600)
    return policy


def verify_installed_archive(root: Path, archive: Path) -> None:
    """Bind every reused archive file/link to the verified installation, not just its marker."""
    with tarfile.open(archive) as source:
        for member in source.getmembers():
            relative = Path(member.name)
            if relative.is_absolute() or ".." in relative.parts:
                raise ValueError("Runner archive has an unsafe member path.")
            installed = root / relative
            if member.isdir():
                if installed.is_symlink() or not installed.is_dir():
                    raise ValueError("Installed runner directory differs from archive.")
            elif member.issym():
                if (not installed.is_symlink() or os.readlink(installed) != member.linkname
                        or not installed.resolve().is_relative_to(root.resolve())):
                    raise ValueError("Installed runner link differs from archive.")
            elif member.isfile() or member.islnk():
                stream = source.extractfile(member)
                if (stream is None or installed.is_symlink() or not installed.is_file()
                        or hashlib.sha256(stream.read()).digest()
                        != hashlib.sha256(installed.read_bytes()).digest()):
                    raise ValueError("Installed runner bytes differ from verified archive.")
            else:
                raise ValueError("Runner archive has an unsupported member kind.")


def register_and_run(run: bool, runner_name="elite-mbp-native", deadline=None, descriptors=()) -> None:
    """Use one repository registration token without printing or persisting it ourselves."""
    def bounds():
        if deadline is None:
            return {}
        remaining = deadline - time.time()
        if remaining <= 0:
            raise ValueError("Registration deadline expired.")
        return {"timeout": min(60, remaining), "pass_fds": tuple(descriptors)}
    result = subprocess.run(
        ["gh", "api", "--method", "POST", "repos/stephenlclarke/elite/actions/runners/registration-token"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, **bounds())
    if result.returncode:
        raise ValueError("Repository runner registration token was unavailable.")
    token = json.loads(result.stdout)["token"]
    environment = dict(os.environ, DEVELOPER_DIR=DEVELOPER)
    configured = subprocess.run(
        [str(RUNNER / "config.sh"), "--url", "https://github.com/stephenlclarke/elite",
         "--token", token, "--name", runner_name, "--labels", "elite-native",
         "--work", "_work", "--unattended", "--ephemeral", "--disableupdate"],
        cwd=RUNNER, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **bounds())
    if configured.returncode:
        raise ValueError("Ephemeral runner registration failed.")
    print("Ephemeral native runner registered with its host-owned exact-head hook.")
    if run:
        completed = subprocess.run([str(RUNNER / "run.sh"), "--once"], cwd=RUNNER, env=environment)
        if completed.returncode:
            raise ValueError("Ephemeral runner process failed.")



RECOVERABLE_ROLES = {"native_checks", "prepare_thread", "prepare_address", "native_phase",
                     "thread_shards", "address_shards", "native_aggregate"}
MAX_SESSION_SECONDS = 7 * 86400


def owned_json(path):
    path = Path(path)
    if not path.is_absolute() or path != path.resolve():
        raise ValueError("Owned input must be an absolute physical path.")
    from native_runner import require_owned_activation_file
    require_owned_activation_file(path)
    if path.stat().st_mode & 0o777 != 0o400:
        raise ValueError("Reviewed/session input must be immutable and owned.")
    return json.loads(path.read_text())


def publish_json(path, value, immutable=False):
    """Keep budget/session state durable before any registration can occur."""
    ensure_owned_directory(path.parent)
    if path.is_symlink():
        raise ValueError("Session state must be physical.")
    temporary = path.with_name(path.name + ".pending-" + str(uuid.uuid4()))
    with temporary.open("x") as destination:
        json.dump(value, destination, sort_keys=True, allow_nan=False)
        destination.write("\n")
        destination.flush()
        os.fsync(destination.fileno())
    temporary.chmod(0o400 if immutable else 0o600)
    temporary.replace(path)
    descriptor = os.open(path.parent, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def reviewed_recoverable_policy(path, checksum, base):
    """Install an explicitly reviewed contract; never synthesize a broader authorization."""
    from native_runner import policy_digest
    path = Path(path)
    if path.is_relative_to(ROOT) or path.is_relative_to(RUNNER):
        raise ValueError("Reviewed policy must be outside checkout and runner data.")
    value = owned_json(path)
    if (not re.fullmatch(r"[0-9a-f]{64}", checksum or "")
            or hashlib.sha256(path.read_bytes()).hexdigest() != checksum
            or set(value) != set(base) | {"recoverable_activation", "recoverable_shards"}
            or any(value[name] != expected for name, expected in base.items())):
        raise ValueError("Reviewed recoverable policy differs from source/archive/toolchain.")
    activation, config = value["recoverable_activation"], value["recoverable_shards"]
    required = {"schema", "enabled", "revoked", "expires_at", "head", "workflow_ref", "workflow_sha256",
                "reusable_workflow_sha256", "manifest_sha256", "runners", "assignment_root", "guard_files"}
    if (not required <= set(activation) or set(activation) - required - {"pr_head"}
            or type(activation["schema"]) is not int or activation["schema"] != 1
            or activation["enabled"] is not True or activation["revoked"] is not False
            or type(activation["expires_at"]) not in (int, float) or not math.isfinite(activation["expires_at"])
            or not time.time() < activation["expires_at"] <= time.time() + MAX_SESSION_SECONDS
            or activation["head"] != base["approved_head"]):
        raise ValueError("Recoverable activation is missing, expired or outside its finite bound.")
    prefix = "stephenlclarke/elite/.github/workflows/ci.yml@"
    if not activation["workflow_ref"].startswith(prefix):
        raise ValueError("Installer supports only the actual required CI caller.")
    ref = activation["workflow_ref"].removeprefix(prefix)
    if ref != "refs/heads/main" and not re.fullmatch(r"refs/pull/[1-9][0-9]*/merge", ref):
        raise ValueError("Recoverable CI ref is outside main/internal PR execution.")
    if ref == "refs/heads/main" and "pr_head" in activation:
        raise ValueError("Main approval must not substitute a PR source identity.")
    if ref.startswith("refs/pull/") and not re.fullmatch(r"[0-9a-f]{40}", activation.get("pr_head", "")):
        raise ValueError("PR source and execution heads must be separately approved.")
    for name, field in (("ci.yml", "workflow_sha256"), ("recoverable-quality.yml", "reusable_workflow_sha256")):
        source = ROOT / ".github/workflows" / name
        if source.is_symlink() or hashlib.sha256(source.read_bytes()).hexdigest() != activation[field]:
            raise ValueError("Reviewed caller/called workflow bytes changed.")
    helpers = {"recoverable_shards.py", "sanitizer_checkpoints.py", "quality_phase_checkpoints.py", "crash_artifacts.py"}
    if set(activation["guard_files"]) != helpers:
        raise ValueError("Recoverable installation requires all five pinned Python files.")
    for name, digest in activation["guard_files"].items():
        source = ROOT / "Tools/CI" / name
        if source.is_symlink() or hashlib.sha256(source.read_bytes()).hexdigest() != digest:
            raise ValueError("Reviewed helper source bytes changed.")
    if len(activation["runners"]) != 1:
        raise ValueError("This installer reserves exactly one physical runner.")
    runner_name, instance = next(iter(activation["runners"].items()))
    if (not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", runner_name)
            or set(instance) != {"workspace", "jobs"}
            or instance["workspace"] != str(RUNNER / "_work/elite/elite")
            or set(instance["jobs"]) != RECOVERABLE_ROLES or len(instance["jobs"]) != len(RECOVERABLE_ROLES)):
        raise ValueError("Recoverable runner/workspace/role reservation differs.")
    if (type(config.get("schema")) is not int or config.get("schema") != 1 or set(config) - {"schema", "host", "cache", "legacy_cache", "workers", "admission", "planning"}
            or set(config.get("workers", {})) != {"one"}
            or config.get("admission", {}).get("explicit") != 1
            or not re.fullmatch(r"[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}", config.get("host", ""))):
        raise ValueError("Recoverable execution needs one approved physical worker and static admission.")
    bounds = config["admission"]
    if (set(bounds) != {"explicit", "cpu_budget", "ram_capacity", "ram_reserve", "peak_per_worker", "disk_capacity", "disk_reserve", "disk_per_worker"}
            or any(type(n) not in (int, float) or not math.isfinite(n) or n <= 0 for n in bounds.values())):
        raise ValueError("Reviewed static admission fields are incomplete.")
    spaces = [Path(config[name]) for name in ("cache", "legacy_cache")]
    spaces += [Path(config["workers"]["one"]), Path(activation["assignment_root"])]
    protected = [ROOT, RUNNER, AUTHORIZATION_ROOT, HOME_ROOT / "recoverable-sessions"]
    if (any(not path.is_absolute() or path != path.resolve() for path in spaces)
            or any(a.is_relative_to(b) or b.is_relative_to(a) for a in spaces for b in protected)
            or any(a.is_relative_to(b) or b.is_relative_to(a) for i, a in enumerate(spaces) for b in spaces[i + 1:])):
        raise ValueError("Reviewed execution/assignment paths overlap mutable or authorization data.")
    manifest = {name: activation[name] for name in ("schema", "enabled", "revoked", "expires_at", "head", "workflow_sha256",
                "reusable_workflow_sha256", "runners", "assignment_root")}
    manifest.update(ref=ref, workflow_file="ci.yml")
    if "pr_head" in activation:
        manifest["pr_head"] = activation["pr_head"]
    if policy_digest(manifest) != activation["manifest_sha256"]:
        raise ValueError("Reviewed published activation manifest is inconsistent.")
    return value


@contextmanager
def recoverable_control():
    """Serialize installation/renewal; the owned listener inherits this lease."""
    ensure_owned_directory(HOME_ROOT)
    path = HOME_ROOT / "recoverable-control.lock"
    descriptor = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, "a") as lock:
        if os.fstat(lock.fileno()).st_uid != os.getuid() or os.fstat(lock.fileno()).st_mode & 0o022:
            raise ValueError("Recoverable control lease is foreign.")
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield lock


@contextmanager
def quiescent_legacy(policy):
    """Check the existing native executor lease; never create a substitute lock."""
    path = Path(policy["recoverable_shards"]["legacy_cache"]) / "executor.lock"
    descriptor = os.open(path, os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "a") as lock:
        if os.fstat(lock.fileno()).st_uid != os.getuid() or os.fstat(lock.fileno()).st_mode & 0o022:
            raise ValueError("Existing physical executor lease is foreign.")
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield


def session_hook(policy, policy_path, guard_path):
    """The fixed hook binds the listener's current ticket before the reviewed native guard."""
    from native_runner import policy_digest
    ticket = HOME_ROOT / "recoverable-sessions/ticket.json"
    check = """import hashlib,json,os,time
from pathlib import Path
try:
    def read(p):
        for n in (p,*p.parents):
            i=n.lstat()
            assert not n.is_symlink() and i.st_uid in (0,os.getuid())
            assert not i.st_mode&0o022 or (n!=p and i.st_uid==0 and i.st_mode&0o1000)
        assert p.stat().st_uid==os.getuid() and p.stat().st_mode&0o777==0o400
        return json.loads(p.read_text())
    p=Path(TICKET)
    t=read(p)
    assert set(t)=={'binding','binding_sha256','ordinal','policy_sha256'}
    assert t['policy_sha256']==POLICY
    assert Path(t['binding']).parent==p.parent and Path(t['binding']).suffix=='.json'
    b=read(Path(t['binding']))
    assert hashlib.sha256(Path(t['binding']).read_bytes()).hexdigest()==t['binding_sha256']
    assert set(b)=={'schema','policy_sha256','head','run_id','run_attempt','max_jobs','expires_at'}
    assert b['schema']==1 and b['policy_sha256']==POLICY and b['head']==HEAD
    assert type(t['ordinal']) is int and 1<=t['ordinal']<=b['max_jobs']<=256
    assert time.time()<b['expires_at']<=EXPIRY
    assert os.environ['GITHUB_RUN_ID']==b['run_id']
    assert os.environ['GITHUB_RUN_ATTEMPT']==b['run_attempt']
except Exception:
    raise SystemExit('Recoverable runner session is not authorized') from None
"""
    check = ("TICKET=" + repr(str(ticket)) + "\nPOLICY=" + repr(policy_digest(policy))
             + "\nHEAD=" + repr(policy["approved_head"]) + "\nEXPIRY=" + repr(policy["recoverable_activation"]["expires_at"]) + "\n" + check)
    return ("#!/bin/bash\nset -euo pipefail\n/usr/bin/python3 -B - <<'PY'\n" + check + "PY\nexec /usr/bin/python3 -B "
            + shlex.quote(str(guard_path)) + " --policy " + shlex.quote(str(policy_path)) + "\n").encode()


def require_registration(policy):
    registration = RUNNER / ".runner"
    from native_runner import require_owned_activation_file
    require_owned_activation_file(registration)
    value = json.loads(registration.read_text())
    name = next(iter(policy["recoverable_activation"]["runners"]))
    if value.get("agentName") != name or value.get("gitHubUrl") != "https://github.com/stephenlclarke/elite" or value.get("workFolder") != "_work":
        raise ValueError("Existing registration is not this approved repository/runner.")


def session_run_active(policy, binding):
    """Read only this exact approved run; a new attempt requires a new session."""
    result = subprocess.run(["gh", "api", "repos/stephenlclarke/elite/actions/runs/" + binding["run_id"]],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                            timeout=min(60, max(1, binding["expires_at"] - time.time())))
    if result.returncode:
        raise ValueError("Workflow run metadata is unavailable; renewal stopped.")
    run = json.loads(result.stdout)
    activation = policy["recoverable_activation"]
    expected = activation.get("pr_head", policy["approved_head"])
    workflow = ".github/workflows/ci.yml"
    ref = activation["workflow_ref"].split("@", 1)[1]
    paths = {workflow, workflow + "@" + ref, workflow + "@" + str(run.get("head_branch")), workflow + "@" + expected}
    if (str(run["id"]) != binding["run_id"] or str(run["run_attempt"]) != binding["run_attempt"]
            or run.get("path") not in paths or run.get("event") not in (("pull_request",) if "pr_head" in activation else ("push", "workflow_dispatch"))
            or run["head_sha"] != expected or run["repository"]["full_name"] != "stephenlclarke/elite"
            or str(run["actor"]["id"]) != "22142777" or str(run["triggering_actor"]["id"]) != "22142777"):
        raise ValueError("Workflow run/attempt/source differs; renewal stopped.")
    if run["status"] == "completed":
        return False
    if run["status"] not in ("queued", "in_progress", "waiting"):
        raise ValueError("Workflow run is not active; renewal stopped.")
    return True


def renew_recoverable(policy_path, run_id, attempt, maximum, expires, register, listen, lock):
    """Consume a finite durable slot before registration; preserve ambiguous listeners."""
    from native_runner import policy_digest
    policy = owned_json(policy_path)
    if (not re.fullmatch(r"[1-9][0-9]*", run_id or "") or not re.fullmatch(r"[1-9][0-9]*", attempt or "")
            or type(maximum) is not int or not 1 <= maximum <= 256 or type(expires) not in (int, float)
            or not math.isfinite(expires) or not time.time() < expires <= policy["recoverable_activation"]["expires_at"]):
        raise ValueError("A finite exact-run/attempt/job/expiry session is required.")
    root = HOME_ROOT / "recoverable-sessions"
    ensure_owned_directory(root)
    binding_path = root / (policy_digest(policy) + "-" + run_id + "-" + attempt + ".json")
    binding = dict(schema=1, policy_sha256=policy_digest(policy), head=policy["approved_head"], run_id=run_id,
                   run_attempt=attempt, max_jobs=maximum, expires_at=expires)
    if binding_path.exists():
        if owned_json(binding_path) != binding:
            raise ValueError("Existing immutable session bounds differ; preserving them.")
    else:
        publish_json(binding_path, binding, immutable=True)
    state_path = binding_path.with_suffix(".state")
    if state_path.exists():
        from native_runner import require_owned_activation_file
        require_owned_activation_file(state_path)
        state = json.loads(state_path.read_text())
        if (set(state) != {"used", "phase"} or type(state["used"]) is not int or not 0 <= state["used"] <= maximum
                or state["phase"] not in ("idle", "registered", "running", "stopped")):
            raise ValueError("Session budget state is invalid.")
    else:
        state = {"used": 0, "phase": "idle"}
    if state["phase"] == "running":
        raise ValueError("Listener outcome is unresolved; preserve it and do not renew.")
    while time.time() < expires:
        if not session_run_active(policy, binding):
            return {"used": state["used"], "reason": "workflow completed"}
        if state["phase"] != "registered":
            if not register or state["used"] >= maximum:
                return {"used": state["used"], "reason": "registration budget exhausted"}
            if (RUNNER / ".runner").exists() or (RUNNER / ".runner").is_symlink():
                raise ValueError("An existing registration must finish before renewal.")
            state.update(used=state["used"] + 1, phase="stopped")
            publish_json(state_path, state)
            publish_json(root / "ticket.json", {"binding": str(binding_path), "binding_sha256": hashlib.sha256(binding_path.read_bytes()).hexdigest(),
                         "ordinal": state["used"], "policy_sha256": policy_digest(policy)}, immutable=True)
            with quiescent_legacy(policy):
                try:
                    register_and_run(False, next(iter(policy["recoverable_activation"]["runners"])),
                                     deadline=expires, descriptors=(lock.fileno(),))
                except subprocess.TimeoutExpired:
                    state["phase"] = "running"
                    publish_json(state_path, state)
                    raise ValueError("Registration outcome is unresolved; no renewal authorized.") from None
            state["phase"] = "registered"
            publish_json(state_path, state)
        require_registration(policy)
        if not listen:
            return {"used": state["used"], "reason": "registered only"}
        state["phase"] = "running"
        publish_json(state_path, state)
        try:
            process = subprocess.Popen([str(RUNNER / "run.sh"), "--once"], cwd=RUNNER,
                                      env={**{key: value for key, value in os.environ.items() if key not in ("GH_TOKEN", "GITHUB_TOKEN")},
                                           "DEVELOPER_DIR": DEVELOPER}, pass_fds=(lock.fileno(),), start_new_session=True)
        except OSError:
            state["phase"] = "registered"
            publish_json(state_path, state)
            raise ValueError("Listener did not launch; registered slot retained.") from None
        while True:
            remaining = expires - time.time()
            if remaining <= 0:
                raise ValueError("Session expired with unresolved listener; no signals or renewal sent.")
            try:
                code = process.wait(timeout=min(30, remaining))
                break
            except subprocess.TimeoutExpired:
                if not session_run_active(policy, binding):
                    # Signal only our unreaped listener, never a native helper or process group.
                    process.send_signal(signal.SIGINT)
                    try:
                        process.wait(timeout=30)
                    except subprocess.TimeoutExpired:
                        raise ValueError("Completed-run listener did not stop; no renewal authorized.") from None
                    state["phase"] = "stopped"
                    publish_json(state_path, state)
                    return {"used": state["used"], "reason": "workflow completed"}
        state["phase"] = "idle" if code == 0 else "stopped"
        publish_json(state_path, state)
        if code != 0:
            raise ValueError("Listener failed; raw runner logs and consumed budget retained.")
        if not register:
            return {"used": state["used"], "reason": "registered slot completed"}
    return {"used": state["used"], "reason": "session expired"}


def registered_session_slot(policy, args):
    """An existing registration is resumable only with its exact durable issued ticket."""
    from native_runner import policy_digest, require_owned_activation_file
    if not args.run:
        raise ValueError("Existing registration requires explicit --run of its issued session slot.")
    root = HOME_ROOT / "recoverable-sessions"
    path = root / (policy_digest(policy) + "-" + str(args.session_run_id) + "-" + str(args.session_run_attempt) + ".json")
    binding = owned_json(path)
    expected = dict(schema=1, policy_sha256=policy_digest(policy), head=policy["approved_head"],
                    run_id=args.session_run_id, run_attempt=args.session_run_attempt,
                    max_jobs=args.max_jobs, expires_at=args.session_expires_at)
    state_path = path.with_suffix(".state")
    require_owned_activation_file(state_path)
    state = json.loads(state_path.read_text())
    ticket = owned_json(root / "ticket.json")
    if (binding != expected or state.get("phase") != "registered"
            or ticket != {"binding": str(path), "binding_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                          "ordinal": state.get("used"), "policy_sha256": policy_digest(policy)}):
        raise ValueError("Existing registration is not this exact issued session; preserving it.")
    return True

def main() -> None:
    """Prepare first; registration and listening require explicit operator flags."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--approved-head", required=True)
    parser.add_argument("--runner-archive", type=Path, required=True)
    parser.add_argument("--archive-sha256", required=True)
    parser.add_argument("--recoverable-policy", type=Path)
    parser.add_argument("--recoverable-policy-sha256")
    parser.add_argument("--session-run-id")
    parser.add_argument("--session-run-attempt")
    parser.add_argument("--max-jobs", type=int)
    parser.add_argument("--session-expires-at", type=float)
    parser.add_argument("--register", action="store_true")
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    if args.recoverable_policy is not None:
        with recoverable_control() as lock:
            # Reading a reviewed policy is allowed; the old executor lease must be quiescent before installation.
            reviewed = owned_json(args.recoverable_policy)
            if (not re.fullmatch(r"[0-9a-f]{64}", args.recoverable_policy_sha256 or "")
                    or hashlib.sha256(args.recoverable_policy.read_bytes()).hexdigest() != args.recoverable_policy_sha256):
                raise ValueError("Reviewed input policy hash differs; no installation attempted.")
            existing = RUNNER / ".runner"
            if existing.is_symlink():
                raise ValueError("Existing registration is not physical.")
            registered = registered_session_slot(reviewed, args) if existing.exists() else False
            with quiescent_legacy(reviewed):
                policy = prepare(args.approved_head, args.runner_archive, args.archive_sha256,
                                 args.recoverable_policy, args.recoverable_policy_sha256, registered=registered)
            print("Prepared recoverable policy: " + str(policy))
            if args.register or args.run:
                result = renew_recoverable(policy, args.session_run_id, args.session_run_attempt, args.max_jobs,
                                          args.session_expires_at, args.register, args.run, lock)
                print(json.dumps(result))
        return
    if any(value is not None for value in (args.recoverable_policy_sha256, args.session_run_id, args.session_run_attempt,
                                           args.max_jobs, args.session_expires_at)):
        raise ValueError("Session flags require explicit recoverable mode.")
    if args.run and not args.register:
        raise ValueError("Listening requires explicit ephemeral registration.")
    policy = prepare(args.approved_head, args.runner_archive, args.archive_sha256)
    print("Prepared host-owned source policy: " + str(policy))
    if args.register:
        register_and_run(args.run)


if __name__ == "__main__":
    try:
        main()
    except (KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit("Native runner preparation failed: " + type(error).__name__) from None
