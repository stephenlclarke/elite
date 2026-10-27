"""Authorize one reviewed Elite quality job on the physical Mac before checkout."""

import argparse
import base64
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import subprocess
import time

REPOSITORY = "stephenlclarke/elite"
ACTOR = "22142777"
RECOVERABLE_JOBS = {"prepare_native", "prepare_thread", "prepare_address", "native_checks", "native_phase",
                    "native_shards", "thread_shards", "address_shards", "native_aggregate"}
PREPARE_JOBS = {"prepare_native", "prepare_thread", "prepare_address", "native_checks"}
SHARD_JOBS = {"native_shards", "thread_shards", "address_shards"}


def workflow_path(environment: dict) -> str:
    """The reusable workflow's caller is the actual CI event/workflow authority."""
    return (".github/workflows/recoverable-quality.yml" if environment.get("GITHUB_EVENT_NAME") == "workflow_dispatch"
            and "/recoverable-quality.yml@" in environment.get("GITHUB_WORKFLOW_REF", "")
            else ".github/workflows/ci.yml")


def require_recoverable_event(activation: dict, environment: dict, event: dict) -> None:
    """Approve the exact execution commit, including a separately pinned internal PR merge."""
    name, ref, head = (environment.get(key, "") for key in ("GITHUB_EVENT_NAME", "GITHUB_REF", "GITHUB_SHA"))
    if name == "pull_request":
        pull = event.get("pull_request", {})
        source, base = pull.get("head", {}), pull.get("base", {})
        # The immutable GitHub execution context is authoritative, not webhook merge metadata.
        valid = (head == activation.get("head")
                 and re.fullmatch(r"[0-9a-f]{40}", head)
                 and activation.get("workflow_ref") == environment.get("GITHUB_WORKFLOW_REF")
                 and activation.get("workflow_ref") == REPOSITORY + "/.github/workflows/ci.yml@" + ref
                 and source.get("sha") == activation.get("pr_head")
                 and re.fullmatch(r"[0-9a-f]{40}", activation.get("pr_head", ""))
                 and source.get("repo", {}).get("full_name") == REPOSITORY
                 and source.get("repo", {}).get("fork") is False
                 and base.get("repo", {}).get("full_name") == REPOSITORY and base.get("ref") == "main"
                 and str(pull.get("user", {}).get("id")) == ACTOR
                 and ref == "refs/pull/" + str(event.get("number")) + "/merge")
    elif name == "push":
        valid = (ref == "refs/heads/main" and event.get("ref") == ref and event.get("after") == head
                 and event.get("deleted") is False and event.get("forced") is False)
    elif name == "workflow_dispatch":
        valid = ref.startswith("refs/heads/")
    else:
        valid = False
    if not valid:
        raise ValueError("Recoverable execution/source/ref is not approved: execution=" + head
                         + ", approved_execution=" + str(activation.get("head"))
                         + ", ref=" + ref)


def assignment_digest(environment: dict) -> str:
    return policy_digest({name: environment.get(name, "") for name in (
        "GITHUB_JOB", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT", "GITHUB_SHA", "RUNNER_NAME",
        "ELITE_RECOVERABLE_REQUEST_MODE", "ELITE_RECOVERABLE_REQUEST_SHARD",
        "ELITE_RECOVERABLE_REQUEST_WORKER", "ELITE_RECOVERABLE_REQUEST_PHASE")})


def assignment_payload(policy: dict, environment: dict) -> dict:
    activation = policy["recoverable_activation"]
    payload = {"schema": 1, "head": policy["approved_head"], "workflow_sha256": activation["workflow_sha256"],
            "activation_sha256": activation["manifest_sha256"], "policy_sha256": policy_digest(policy),
            "run_id": environment["GITHUB_RUN_ID"], "run_attempt": environment["GITHUB_RUN_ATTEMPT"],
            "job": environment["GITHUB_JOB"], "runner": environment["RUNNER_NAME"],
            "workspace": environment["GITHUB_WORKSPACE"], "policy_path": environment["ELITE_NATIVE_POLICY"],
            "mode": environment.get("ELITE_RECOVERABLE_REQUEST_MODE", ""),
            "shard": environment.get("ELITE_RECOVERABLE_REQUEST_SHARD", ""),
            "worker": environment.get("ELITE_RECOVERABLE_REQUEST_WORKER", ""),
            "phase": environment.get("ELITE_RECOVERABLE_REQUEST_PHASE", ""),
            "plan_sha256": environment.get("PLAN_DIGEST") or None}
    if environment.get("GITHUB_JOB") == "native_aggregate":
        payload["other_plan_sha256"] = environment.get("OTHER_PLAN_DIGEST") or None
    return payload


def require_owned_assignment(policy: dict, environment: dict, current: float) -> None:
    activation = policy["recoverable_activation"]
    root = Path(activation["assignment_root"])
    spaces = [Path(instance["workspace"]) for instance in activation["runners"].values()]
    config = policy.get("recoverable_shards", {})
    spaces.extend(Path(path) for path in config.get("workers", {}).values())
    spaces.extend(Path(config[name]) for name in ("cache", "legacy_cache") if name in config)
    if any(root.is_relative_to(path) or path.is_relative_to(root) for path in spaces):
        raise ValueError("Owned assignment storage overlaps mutable execution data.")
    expected = root / (assignment_digest(environment) + ".json")
    if (not root.is_absolute() or root != root.resolve()
            or environment.get("ELITE_RECOVERABLE_ASSIGNMENT_PATH") != str(expected)):
        raise ValueError("Assignment is outside host-owned authorization storage.")
    require_owned_activation_file(expected)
    binding = json.loads(expected.read_text())
    payload = assignment_payload(policy, environment)
    if (not isinstance(binding, dict) or set(binding) != set(payload) | {"expires_at", "revoked"}
            or type(binding["schema"]) is not int or type(binding["expires_at"]) not in (int, float)
            or not math.isfinite(binding["expires_at"])
            or {name: binding[name] for name in payload} != payload
            or binding["revoked"] is not False or not current < binding["expires_at"] <= activation["expires_at"]
            or environment.get("ELITE_RECOVERABLE_ASSIGNMENT_SHA256") != policy_digest(binding)):
        raise ValueError("Owned assignment is stale, revoked or differs from this exact job.")


def policy_digest(policy: dict) -> str:
    return hashlib.sha256(json.dumps(policy, sort_keys=True, separators=(",", ":"),
                                     allow_nan=False).encode()).hexdigest()


def require_recoverable_job(policy: dict, environment: dict, event: dict, now=None, verify_assignment=True) -> dict:
    """An optional host-owned contract grants only this reviewed manual workflow and instance."""
    activation = policy.get("recoverable_activation", {})
    approved = policy.get("approved_head", "")
    workflow = REPOSITORY + "/" + workflow_path(environment) + "@" + environment.get("GITHUB_REF", "")
    current = time.time() if now is None else now
    if (type(activation.get("schema")) is not int or activation.get("schema") != 1 or activation.get("enabled") is not True
            or activation.get("revoked") is not False
            or type(activation.get("expires_at")) not in (int, float)
            or not math.isfinite(activation["expires_at"])
            or not current < activation["expires_at"]
            or not re.fullmatch(r"[0-9a-f]{40}", approved)
            or activation.get("head") != approved
            or environment.get("GITHUB_SHA") != approved
            or activation.get("workflow_ref") != workflow
            or environment.get("GITHUB_WORKFLOW_REF") != workflow
            or environment.get("GITHUB_REPOSITORY") != REPOSITORY
            or environment.get("GITHUB_ACTOR_ID") != ACTOR
            or event.get("repository", {}).get("full_name") != REPOSITORY
            or event.get("repository", {}).get("fork") is not False
            or str(event.get("sender", {}).get("id")) != ACTOR
            or environment.get("GITHUB_JOB") not in RECOVERABLE_JOBS):
        raise ValueError("Recoverable native job is not explicitly activated.")
    require_recoverable_event(activation, environment, event)
    for name, field in (("ELITE_RECOVERABLE_WORKFLOW_SHA256", "workflow_sha256"),
                        ("ELITE_RECOVERABLE_ACTIVATION_SHA256", "manifest_sha256")):
        expected = activation.get(field, "")
        if not re.fullmatch(r"[0-9a-f]{64}", expected) or environment.get(name) != expected:
            raise ValueError("Recoverable native workflow/manifest attestation changed.")
    if environment.get("ELITE_RECOVERABLE_POLICY_SHA256") != policy_digest(policy):
        raise ValueError("Recoverable native policy identity changed.")
    if (environment.get("ELITE_NATIVE_APPROVED_HEAD") != approved
            or not Path(environment.get("ELITE_NATIVE_POLICY", "")).is_absolute()):
        raise ValueError("Legacy native approval/policy controls are missing or inconsistent.")
    if verify_assignment and environment.get("ELITE_RECOVERABLE_CODE_ENABLED") != "true":
        raise ValueError("Installed recoverable code was not activated by the owned hook.")
    mode, shard, worker, phase = (environment.get("ELITE_RECOVERABLE_REQUEST_" + name, "")
                                  for name in ("MODE", "SHARD", "WORKER", "PHASE"))
    job = environment["GITHUB_JOB"]
    if job == "native_aggregate" and not re.fullmatch(r"[0-9a-f]{64}", environment.get("OTHER_PLAN_DIGEST", "")):
        raise ValueError("The independently prepared address plan is mandatory")
    if ((job in ("prepare_native", "native_aggregate", "native_checks") and any((mode, shard, worker, phase)))
            or (job == "native_phase" and (phase not in ("normal", "leaks") or any((mode, shard, worker))))
            or (job in ("prepare_thread", "prepare_address") and (mode != job.removeprefix("prepare_") or any((shard, worker, phase))))
            or (job in SHARD_JOBS and (mode not in ("thread", "address")
                or not re.fullmatch(r"[0-9a-f]{64}", shard) or worker not in ("one", "two") or phase
                or (job == "thread_shards" and mode != "thread") or (job == "address_shards" and mode != "address")))):
        raise ValueError("Recoverable role does not match its exact request type.")
    if environment["GITHUB_JOB"] not in PREPARE_JOBS:
        plan = environment.get("PLAN_DIGEST", "")
        if (not re.fullmatch(r"[0-9a-f]{64}", plan)
                or (verify_assignment and (environment.get("ELITE_RECOVERABLE_PLAN_SHA256") != plan
                    or not re.fullmatch(r"[0-9a-f]{64}", environment.get("ELITE_RECOVERABLE_ASSIGNMENT_SHA256", ""))))):
            raise ValueError("Recoverable frozen plan/assignment attestation changed.")
    elif environment.get("PLAN_DIGEST") or environment.get("ELITE_RECOVERABLE_PLAN_SHA256"):
        raise ValueError("Preparation cannot claim a preexisting frozen plan.")
    instance = activation.get("runners", {}).get(environment.get("RUNNER_NAME"), {})
    workspace = Path(environment.get("GITHUB_WORKSPACE", ""))
    if (environment.get("GITHUB_JOB") not in instance.get("jobs", [])
            or not set(instance.get("jobs", [])) <= RECOVERABLE_JOBS
            or not workspace.is_absolute() or str(workspace) != instance.get("workspace")
            or workspace.parts[-3:] != ("_work", "elite", "elite")
            or workspace != workspace.resolve()):
        raise ValueError("Recoverable native runner/workspace is not reserved.")
    if not all(re.fullmatch(r"[1-9][0-9]*", environment.get(name, "")) for name in ("GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")):
        raise ValueError("Recoverable job has no exact run attempt identity.")
    if verify_assignment:
        require_owned_assignment(policy, environment, current)
    return activation


def load_recoverable_guard(policy: dict):
    """Only the separately installed, hash-pinned host package may authorize before checkout."""
    import importlib
    directory = Path(__file__).resolve().parent
    spaces = [Path(instance["workspace"]) for instance in policy["recoverable_activation"]["runners"].values()]
    config = policy["recoverable_shards"]
    spaces.extend(Path(path) for path in config["workers"].values())
    spaces.extend(Path(config[name]) for name in ("cache", "legacy_cache"))
    if any(directory.is_relative_to(path) or path.is_relative_to(directory) for path in spaces):
        raise ValueError("Installed guard overlaps mutable checkouts/cache.")
    require_owned_activation_file(Path(__file__))
    if hashlib.sha256(Path(__file__).read_bytes()).hexdigest() != policy["guard_sha256"]:
        raise ValueError("Installed native guard bytes changed.")
    required = {"recoverable_shards.py", "sanitizer_checkpoints.py", "quality_phase_checkpoints.py", "crash_artifacts.py"}
    hashes = policy["recoverable_activation"]["guard_files"]
    if set(hashes) != required:
        raise ValueError("Installed recoverable guard package is incomplete.")
    for name, digest in hashes.items():
        path = directory / name
        require_owned_activation_file(path)
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError("Installed recoverable guard dependency changed.")
    module = importlib.import_module("recoverable_shards")
    if Path(module.__file__).resolve() != directory / "recoverable_shards.py":
        raise ValueError("Recoverable guard was imported from outside the owned package.")
    return module


def authorize_recoverable(policy: dict, environment: dict, event: dict, api=None, guard=None, now=None) -> dict:
    """Pre-job hook: authenticate GitHub source/plan, then issue one owned run-attempt assignment."""
    current = time.time() if now is None else now
    activation, value = policy["recoverable_activation"], dict(environment)
    value.update(ELITE_RECOVERABLE_POLICY_SHA256=policy_digest(policy),
                 ELITE_RECOVERABLE_WORKFLOW_SHA256=activation["workflow_sha256"],
                 ELITE_RECOVERABLE_ACTIVATION_SHA256=activation["manifest_sha256"])
    require_recoverable_job(policy, value, event, current, verify_assignment=False)
    manifest = json.loads(value["ACTIVATION"])
    policies = json.loads(value["POLICY_DIGESTS"])
    if (policy_digest(manifest) != activation["manifest_sha256"]
            or set(policies) != set(activation["runners"])
            or set(policies.values()) != {policy_digest(policy)}
            or policies.get(value["RUNNER_NAME"]) != policy_digest(policy)
            or manifest["ref"] != value["GITHUB_REF"]
            or any(manifest[name] != activation[name] for name in (
                "schema", "enabled", "revoked", "expires_at", "head", "workflow_sha256", "runners", "assignment_root"))):
        raise ValueError("Job activation variables differ from the host-owned approval.")
    for name in ("pr_head", "reusable_workflow_sha256"):
        if manifest.get(name) != activation.get(name):
            raise ValueError("Owned caller/PR activation facts differ.")
    guard = load_recoverable_guard(policy) if guard is None else guard
    if not guard.PHYSICAL_EXECUTION_ENABLED:
        raise ValueError("Recoverable native execution HELD by the installed guard.")
    token = value.get("GITHUB_TOKEN") or value.get("GH_TOKEN")
    if not token:
        raise ValueError("Pre-job artifact read credentials are unavailable.")
    value["GITHUB_TOKEN"], value["GH_TOKEN"] = token, token
    api = api or (lambda path: json.loads(subprocess.check_output(
        ["gh", "api", path], env=value, stderr=subprocess.PIPE, timeout=60)))
    source = api(f"repos/{REPOSITORY}/contents/{workflow_path(value)}?ref={policy['approved_head']}")
    if (source["encoding"] != "base64" or hashlib.sha256(base64.b64decode(source["content"])).hexdigest()
            != activation["workflow_sha256"]):
        raise ValueError("GitHub workflow bytes differ from host approval.")
    if workflow_path(value).endswith("ci.yml"):
        called = api(f"repos/{REPOSITORY}/contents/.github/workflows/recoverable-quality.yml?ref={policy['approved_head']}")
        if hashlib.sha256(base64.b64decode(called["content"])).hexdigest() != activation.get("reusable_workflow_sha256"):
            raise ValueError("Called quality workflow differs from host approval.")
    entries = api(f"repos/{REPOSITORY}/contents/Tools/CI?ref={policy['approved_head']}")
    blobs = {entry["name"]: entry["sha"] for entry in entries if entry["type"] == "file"}
    for name in ("native_runner.py", "recoverable_shards.py", "sanitizer_checkpoints.py",
                 "quality_phase_checkpoints.py", "crash_artifacts.py"):
        raw = (Path(__file__).resolve().parent / name).read_bytes()
        # Git's blob format is SHA-1; the installed package also has independent SHA-256 pins.
        blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw, usedforsecurity=False).hexdigest()
        if blobs.get(name) != blob:
            raise ValueError("Installed authorizer package differs from the approved commit.")
    from types import SimpleNamespace
    config = policy["recoverable_shards"]
    authority = SimpleNamespace(environment=value, policy=policy, config=config, cache=Path(config["cache"]),
                                workers={name: Path(path) for name, path in config["workers"].items()})
    remote = guard.GitHubArtifacts(authority, api=api)
    if value["GITHUB_JOB"] not in PREPARE_JOBS:
        artifact_id = value.get("PLAN_ID", "")
        if not re.fullmatch(r"[1-9][0-9]*", artifact_id):
            raise ValueError("No trusted prepared artifact identity.")
        artifact = api(f"repos/{REPOSITORY}/actions/artifacts/{artifact_id}")
        if not artifact["name"].startswith("native-plan-"):
            raise ValueError("Pre-job artifact is not an owned prepared plan.")
        bundle = remote.fetch(artifact, value.get("PLAN_ARCHIVE"))
        plans, manifest = guard.NativeWorkflow(authority, remote).plans(bundle, value["PLAN_DIGEST"])
        if manifest["host"] != config["host"]:
            raise ValueError("Prepared plan belongs to another physical host.")
        if value["GITHUB_JOB"] in SHARD_JOBS:
            assignment = {"mode": value.get("ELITE_RECOVERABLE_REQUEST_MODE"),
                          "shard": value.get("ELITE_RECOVERABLE_REQUEST_SHARD"),
                          "worker": value.get("ELITE_RECOVERABLE_REQUEST_WORKER")}
            if assignment not in manifest["expected"]:
                raise ValueError("This worker/shard is not in the authenticated frozen plan.")
        if value["GITHUB_JOB"] == "native_phase" and value.get("ELITE_RECOVERABLE_REQUEST_PHASE") not in manifest["phases"]:
            raise ValueError("This phase is not in the authenticated frozen plan.")
        if value["GITHUB_JOB"] == "native_aggregate":
            other_id = value.get("OTHER_PLAN_ID", "")
            if not re.fullmatch(r"[1-9][0-9]*", other_id):
                raise ValueError("Aggregate requires the independent address plan artifact.")
            other_artifact = api(f"repos/{REPOSITORY}/actions/artifacts/{other_id}")
            if not other_artifact["name"].startswith("native-plan-"):
                raise ValueError("Aggregate second artifact is not a mode plan.")
            other_bundle = remote.fetch(other_artifact, value.get("OTHER_PLAN_ARCHIVE"))
            other_plans, _ = guard.NativeWorkflow(authority, remote).plans(other_bundle, value["OTHER_PLAN_DIGEST"])
            if ({p["runtime"]["mode"] for p in plans} != {"thread"}
                    or {p["runtime"]["mode"] for p in other_plans} != {"address"}):
                raise ValueError("Aggregate mode prerequisites differ.")
        value["ELITE_RECOVERABLE_PLAN_SHA256"] = value["PLAN_DIGEST"]
    root = Path(activation["assignment_root"])
    workspace = Path(value["GITHUB_WORKSPACE"])
    if root.is_relative_to(workspace) or workspace.is_relative_to(root):
        raise ValueError("Owned assignment storage overlaps the job checkout.")
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    binding = {**assignment_payload(policy, value), "expires_at": min(activation["expires_at"], current + 28800),
               "revoked": False}
    path = root / (assignment_digest(value) + ".json")
    if path.exists():
        require_owned_activation_file(path)
        prior = json.loads(path.read_text())
        payload = assignment_payload(policy, value)
        if ({name: prior[name] for name in payload} != payload or prior["revoked"] is not False
                or not current < prior["expires_at"] <= activation["expires_at"]):
            raise ValueError("An existing assignment cannot be overwritten.")
        binding = prior
    else:
        temporary = path.with_suffix(".pending")
        with temporary.open("x") as output:
            json.dump(binding, output, sort_keys=True)
            output.flush()
            os.fsync(output.fileno())
        temporary.chmod(0o400)
        temporary.replace(path)
        descriptor = os.open(root, os.O_RDONLY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    value.update(ELITE_RECOVERABLE_ASSIGNMENT_PATH=str(path),
                 ELITE_RECOVERABLE_ASSIGNMENT_SHA256=policy_digest(binding), ELITE_RECOVERABLE_CODE_ENABLED="true")
    require_recoverable_job(policy, value, event, current)
    return value


def require_owned_activation_file(path: Path) -> None:
    """The optional extension cannot come from a linked or writable policy ancestry."""
    for node in (path, *path.parents):
        info = node.lstat()
        sticky_system_parent = node != path and info.st_uid == 0 and info.st_mode & 0o1000
        if node.is_symlink() or info.st_uid not in (0, os.getuid()) or (info.st_mode & 0o022 and not sticky_system_parent):
            raise ValueError("Activation policy ancestry is not immutable and owned.")
    if path.stat().st_uid != os.getuid():
        raise ValueError("Activation policy must belong to the runner owner.")


def require_trusted_job(environment: dict, event: dict, approved_head: str) -> None:
    """Reject all other repositories, actors, workflows, forks and source revisions."""
    if not re.fullmatch(r"[0-9a-f]{40}", approved_head):
        raise ValueError("Invalid approved source identity.")
    repository = event.get("repository", {})
    if not (environment.get("GITHUB_REPOSITORY") == REPOSITORY
            and environment.get("GITHUB_ACTOR_ID") == ACTOR
            and environment.get("GITHUB_JOB") == "quality"
            and repository.get("full_name") == REPOSITORY
            and repository.get("fork") is False
            and str(event.get("sender", {}).get("id")) == ACTOR):
        raise ValueError("Native quality accepts only the approved internal job.")
    workflow = environment.get("GITHUB_WORKFLOW_REF", "")
    if not workflow.startswith(REPOSITORY + "/.github/workflows/ci.yml@refs/"):
        raise ValueError("Native quality requires its reviewed CI workflow.")
    name = environment.get("GITHUB_EVENT_NAME")
    if name == "pull_request":
        pull = event.get("pull_request", {})
        head = pull.get("head", {})
        base = pull.get("base", {})
        valid = (head.get("sha") == approved_head
                 and head.get("repo", {}).get("full_name") == REPOSITORY
                 and head.get("repo", {}).get("fork") is False
                 and base.get("repo", {}).get("full_name") == REPOSITORY
                 and base.get("ref") == "main"
                 and str(pull.get("user", {}).get("id")) == ACTOR)
    elif name == "push":
        valid = (environment.get("GITHUB_REF") == "refs/heads/main"
                 and event.get("ref") == "refs/heads/main"
                 and event.get("after") == approved_head
                 and environment.get("GITHUB_SHA") == approved_head
                 and event.get("deleted") is False
                 and event.get("forced") is False)
    elif name == "workflow_dispatch":
        valid = (environment.get("GITHUB_SHA") == approved_head
                 and environment.get("GITHUB_REF", "").startswith("refs/heads/"))
    else:
        valid = False
    if not valid:
        raise ValueError("Native quality source or event is not approved.")


def output(*args: str) -> str:
    """Read a tool identity without shell interpolation."""
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE).strip()


def require_physical_host(policy: dict, environment: dict) -> Path:
    """Keep this runner separate from the VM and confined to its owned checkout."""
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise ValueError("Native quality requires the physical Apple Silicon Mac.")
    if output("sysctl", "-n", "hw.model").startswith("VirtualMac"):
        raise ValueError("The isolated VM is not the native quality runner.")
    root = Path(policy["runner_root"]).resolve()
    workspace = Path(environment["GITHUB_WORKSPACE"]).resolve()
    if workspace != root / "_work" / "elite" / "elite":
        raise ValueError("Native quality requires its dedicated owned checkout.")
    if environment.get("DEVELOPER_DIR") != policy["developer_dir"]:
        raise ValueError("Native quality developer directory changed.")
    if output("swift", "--version") != policy["swift"]:
        raise ValueError("Native quality compiler changed.")
    if output("xcrun", "--sdk", "macosx", "--show-sdk-version") != policy["sdk"]:
        raise ValueError("Native quality SDK changed.")
    return workspace


def validate(policy: dict, environment: dict) -> Path:
    """Validate the immutable pre-job metadata before any workflow checkout or action."""
    event = json.loads(Path(environment["GITHUB_EVENT_PATH"]).read_text())
    if environment.get("GITHUB_JOB") in RECOVERABLE_JOBS:
        activation = require_recoverable_job(policy, environment, event)
        if platform.system() != "Darwin" or platform.machine() != "arm64":
            raise ValueError("Recoverable native jobs require physical Apple Silicon.")
        hardware = output("ioreg", "-rd1", "-c", "IOPlatformExpertDevice")
        uuids = re.findall(r'"IOPlatformUUID"\s*=\s*"([0-9A-Fa-f-]{36})"', hardware)
        if len(uuids) != 1 or uuids[0].upper() != policy["recoverable_shards"]["host"]:
            raise ValueError("Recoverable job is assigned to another physical host.")
        # One shared host-owned policy may name multiple exact runner instances.
        instance = activation["runners"][environment["RUNNER_NAME"]]
        root = Path(instance["workspace"]).parents[2]
        return require_physical_host(dict(policy, runner_root=str(root)), environment)
    else:
        require_trusted_job(environment, event, policy["approved_head"])
    return require_physical_host(policy, environment)


def require_recoverable_checkout(policy: dict, environment: dict, workspace: Path) -> None:
    if environment.get("GITHUB_JOB") in RECOVERABLE_JOBS:
        path = workspace / workflow_path(environment)
        if (path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest()
                != policy["recoverable_activation"]["workflow_sha256"]):
            raise ValueError("Checked-out recoverable workflow bytes changed.")
        if workflow_path(environment).endswith("ci.yml"):
            called = workspace / ".github/workflows/recoverable-quality.yml"
            if called.is_symlink() or hashlib.sha256(called.read_bytes()).hexdigest() != policy["recoverable_activation"].get("reusable_workflow_sha256"):
                raise ValueError("Checked-out called quality workflow bytes changed.")


def main() -> None:
    """Run from the host-owned hook, or recheck the checked-out source before make ci."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", default=os.environ.get("ELITE_NATIVE_POLICY"))
    parser.add_argument("--checkout", action="store_true")
    args = parser.parse_args()
    if not args.policy:
        raise ValueError("A host-owned native policy is required.")
    policy_path = Path(args.policy)
    if policy_path.is_symlink() or policy_path.stat().st_uid != os.getuid() or policy_path.stat().st_mode & 0o022:
        raise ValueError("Native policy must be an owned physical file.")
    policy = json.loads(policy_path.read_text())
    if "recoverable_activation" in policy:
        require_owned_activation_file(policy_path)
    environment = dict(os.environ)
    if environment.get("GITHUB_JOB") in RECOVERABLE_JOBS:
        if (environment.get("ELITE_NATIVE_POLICY", str(policy_path.resolve())) != str(policy_path.resolve())
                or environment.get("ELITE_NATIVE_APPROVED_HEAD", policy["approved_head"]) != policy["approved_head"]):
            raise ValueError("Hook arguments differ from the native approval environment.")
        environment.update(ELITE_NATIVE_POLICY=str(policy_path.resolve()), ELITE_NATIVE_APPROVED_HEAD=policy["approved_head"])
    if not args.checkout and environment.get("GITHUB_JOB") in RECOVERABLE_JOBS:
        event = json.loads(Path(environment["GITHUB_EVENT_PATH"]).read_text())
        environment = authorize_recoverable(policy, environment, event)
    workspace = validate(policy, environment)
    if args.checkout:
        if Path.cwd().resolve() != workspace:
            raise ValueError("Native quality checkout location changed.")
        if output("git", "rev-parse", "HEAD") != environment.get("GITHUB_SHA"):
            raise ValueError("Native checkout does not match the assigned revision.")
        require_recoverable_checkout(policy, environment, workspace)
        from local_runner import cache_key, clean_checkout, prepare_build_cache
        prepare_build_cache(workspace, cache_key(workspace, policy["swift"], policy["sdk"]))
        clean_checkout(workspace)
    else:
        # The hook is installed outside the runner/checkout and executes before workflow steps.
        with Path(environment["GITHUB_ENV"]).open("a") as destination:
            destination.write("ELITE_NATIVE_APPROVED_HEAD=" + policy["approved_head"] + "\n")
            destination.write("ELITE_NATIVE_POLICY=" + str(policy_path.resolve()) + "\n")
            if environment.get("GITHUB_JOB") in RECOVERABLE_JOBS:
                for name in ("ELITE_RECOVERABLE_POLICY_SHA256", "ELITE_RECOVERABLE_WORKFLOW_SHA256",
                             "ELITE_RECOVERABLE_ACTIVATION_SHA256", "ELITE_RECOVERABLE_ASSIGNMENT_PATH",
                             "ELITE_RECOVERABLE_ASSIGNMENT_SHA256", "ELITE_RECOVERABLE_CODE_ENABLED",
                             "ELITE_RECOVERABLE_PLAN_SHA256"):
                    if name in environment:
                        destination.write(name + "=" + environment[name] + "\n")
    print(json.dumps({"approvedHead": policy["approved_head"], "physicalHost": True,
                      "swift": policy["swift"], "sdk": policy["sdk"]}))


if __name__ == "__main__":
    try:
        main()
    except (KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        # Do not print event payloads, commands or registration credentials on a public job.
        raise SystemExit("Native quality authorization failed: " + type(error).__name__) from None
