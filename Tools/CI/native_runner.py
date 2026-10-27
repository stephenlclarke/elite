"""Authorize one reviewed Elite quality job on the physical Mac before checkout."""

import argparse
import json
import os
from pathlib import Path
import platform
import re
import subprocess

REPOSITORY = "stephenlclarke/elite"
ACTOR = "22142777"


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
    require_trusted_job(environment, event, policy["approved_head"])
    return require_physical_host(policy, environment)


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
    environment = dict(os.environ)
    workspace = validate(policy, environment)
    if args.checkout:
        if Path.cwd().resolve() != workspace:
            raise ValueError("Native quality checkout location changed.")
        if output("git", "rev-parse", "HEAD") != environment.get("GITHUB_SHA"):
            raise ValueError("Native checkout does not match the assigned revision.")
        from local_runner import cache_key, clean_checkout, prepare_build_cache
        prepare_build_cache(workspace, cache_key(workspace, policy["swift"], policy["sdk"]))
        clean_checkout(workspace)
    else:
        # The hook is installed outside the runner/checkout and executes before workflow steps.
        with Path(environment["GITHUB_ENV"]).open("a") as destination:
            destination.write("ELITE_NATIVE_APPROVED_HEAD=" + policy["approved_head"] + "\n")
            destination.write("ELITE_NATIVE_POLICY=" + str(policy_path.resolve()) + "\n")
    print(json.dumps({"approvedHead": policy["approved_head"], "physicalHost": True,
                      "swift": policy["swift"], "sdk": policy["sdk"]}))


if __name__ == "__main__":
    try:
        main()
    except (KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        # Do not print event payloads, commands or registration credentials on a public job.
        raise SystemExit("Native quality authorization failed: " + type(error).__name__) from None
