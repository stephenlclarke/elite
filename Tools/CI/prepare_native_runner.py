"""Prepare an ephemeral physical runner with an immutable, host-owned exact-head hook."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
HOME_ROOT = Path.home() / "Library/Application Support/EliteCI"
RUNNER = HOME_ROOT / "native-runner"
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


def prepare(approved: str, archive: Path, archive_hash: str) -> Path:
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
    authorization = HOME_ROOT / "native-authorization" / approved
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
    policy_bytes = (json.dumps(expected_policy, indent=2) + "\n").encode()
    hook_bytes = ("#!/bin/bash\nset -euo pipefail\nexec /usr/bin/python3 "
                  + shlex.quote(str(guard_copy)) + " --policy " + shlex.quote(str(policy)) + "\n").encode()
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
            raise ValueError("The previous runner registration is still active.")
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
             (hook, hook_bytes, 0o500)]
    if authorization.is_symlink():
        raise ValueError("Authorization directory must be physical.")
    if authorization.exists():
        ensure_owned_directory(authorization)
        for path, expected, mode in files:
            if (path.is_symlink() or not path.is_file() or path.stat().st_uid != os.getuid()
                    or path.stat().st_mode & 0o777 != mode or path.read_bytes() != expected):
                raise ValueError("Existing immutable authorization differs; preserving it.")
    else:
        authorization.mkdir(parents=True, exist_ok=False, mode=0o700)
        for path, data, mode in files:
            with path.open("xb") as destination:
                destination.write(data)
            path.chmod(mode)
    if (RUNNER / ".env").is_symlink():
        raise ValueError("Runner environment file is not physical.")
    (RUNNER / ".env").write_text("ACTIONS_RUNNER_HOOK_JOB_STARTED=" + str(hook)
                                + "\nDEVELOPER_DIR=" + DEVELOPER + "\n")
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


def register_and_run(run: bool) -> None:
    """Use one repository registration token without printing or persisting it ourselves."""
    result = subprocess.run(
        ["gh", "api", "--method", "POST", "repos/stephenlclarke/elite/actions/runners/registration-token"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode:
        raise ValueError("Repository runner registration token was unavailable.")
    token = json.loads(result.stdout)["token"]
    environment = dict(os.environ, DEVELOPER_DIR=DEVELOPER)
    configured = subprocess.run(
        [str(RUNNER / "config.sh"), "--url", "https://github.com/stephenlclarke/elite",
         "--token", token, "--name", "elite-mbp-native", "--labels", "elite-native",
         "--work", "_work", "--unattended", "--ephemeral", "--disableupdate"],
        cwd=RUNNER, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if configured.returncode:
        raise ValueError("Ephemeral runner registration failed.")
    print("Ephemeral native runner registered with its host-owned exact-head hook.")
    if run:
        completed = subprocess.run([str(RUNNER / "run.sh"), "--once"], cwd=RUNNER, env=environment)
        if completed.returncode:
            raise ValueError("Ephemeral runner process failed.")


def main() -> None:
    """Prepare first; registration and listening require explicit operator flags."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--approved-head", required=True)
    parser.add_argument("--runner-archive", type=Path, required=True)
    parser.add_argument("--archive-sha256", required=True)
    parser.add_argument("--register", action="store_true")
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
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
