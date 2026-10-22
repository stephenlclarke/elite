"""Keep trusted unit jobs in the pinned VM and retain its incremental build."""

import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[2]
SWIFT = "Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)"


def require_trusted_push(environment: dict[str, str], event: dict) -> None:
    """Reject a misrouted PR, fork, repository or actor before preparing a cache."""
    repository = event.get("repository", {})
    if not (
        environment.get("GITHUB_EVENT_NAME") == "push"
        and environment.get("GITHUB_REPOSITORY") == "stephenlclarke/elite"
        and environment.get("GITHUB_ACTOR_ID") == "22142777"
        and repository.get("full_name") == "stephenlclarke/elite"
        and repository.get("fork") is False
    ):
        raise ValueError("Local runner accepts only Stephen's internal Elite pushes.")


def cache_key(root: Path, swift: str, sdk: str) -> str:
    """Separate incompatible compilers, SDKs, packages and build modes."""
    digest = hashlib.sha256()
    for value in (swift, sdk, "arm64:swift-test:jobs3:coverage"):
        digest.update(value.encode() + b"\0")
    for name in ("Package.swift", "Package.resolved"):
        digest.update(name.encode() + b"\0")
        path = root / name
        digest.update(path.read_bytes() if path.is_file() else b"<absent>")
        digest.update(b"\0")
    return digest.hexdigest()


def prepare_build_cache(root: Path, key: str) -> Path:
    """Keep an owned physical build directory inside crash-evidence confinement."""
    if len(key) != 64 or any(c not in "0123456789abcdef" for c in key):
        raise ValueError("Invalid build-cache identity.")
    build = root / ".build"
    marker = build / "elite-ci-cache.json"
    if build.is_symlink() or (build.exists() and not build.is_dir()):
        raise ValueError("Existing .build is not a physical directory; preserving it.")
    if build.exists():
        if marker.is_symlink() or not marker.is_file():
            raise ValueError("Existing .build has no owned cache identity; preserving it.")
        previous = json.loads(marker.read_text())
        if not isinstance(previous, dict) or previous.get("owner") != "elite-ci":
            raise ValueError("Existing .build has a foreign cache identity; preserving it.")
        previous_key = previous.get("key", "")
        if (not isinstance(previous_key, str) or len(previous_key) != 64
                or any(c not in "0123456789abcdef" for c in previous_key)):
            raise ValueError("Existing cache identity is malformed; preserving it.")
        if previous_key != key:
            shutil.rmtree(build)
    build.mkdir(parents=True, exist_ok=True, mode=0o700)
    marker.write_text(json.dumps({"owner": "elite-ci", "key": key}) + "\n")
    return build


def clean_checkout(root: Path) -> None:
    """Remove other ignored/untracked inputs while retaining only root .build."""
    subprocess.run(["git", "clean", "-ffdx", "-e", "/.build/"], cwd=root,
                   check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def output(*args: str) -> str:
    """Read a tool fingerprint without executing shell text."""
    return subprocess.check_output(args, text=True).strip()


def main() -> None:
    """Verify the VM and toolchain before connecting its persistent cache."""
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    require_trusted_push(dict(os.environ), event)
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise ValueError("Local runner requires Apple Silicon macOS.")
    if not output("sysctl", "-n", "hw.model").startswith("VirtualMac"):
        raise ValueError("Local runner must execute inside the isolated macOS VM.")
    swift = output("swift", "--version")
    sdk = output("xcrun", "--sdk", "macosx", "--show-sdk-version")
    if swift.splitlines()[0] != SWIFT or sdk != "15.5":
        raise ValueError("Local runner must match Swift 6.1.2 and macOS SDK 15.5.")
    key = cache_key(ROOT, swift, sdk)
    cache = prepare_build_cache(ROOT, key)
    clean_checkout(ROOT)
    print(json.dumps({"swift": swift, "sdk": sdk, "cache": str(cache), "key": key}))


if __name__ == "__main__":
    main()
