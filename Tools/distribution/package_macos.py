#!/usr/bin/env python3
"""Build a signed macOS ZIP from a committed source checkpoint."""

import argparse
import datetime
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def run(*arguments, capture=False, check=True):
    """Run a distribution tool without logging credential-bearing arguments."""
    result = subprocess.run(
        arguments, cwd=ROOT, text=True, capture_output=capture, check=False
    )
    if check and result.returncode:
        raise RuntimeError(
            f"{Path(arguments[0]).name} failed (exit {result.returncode})."
        )
    return result


def source_checkpoint():
    """Refuse to label modified/untracked maintained source as a committed build."""
    if run(
        "git", "status", "--porcelain", "--untracked-files=no", capture=True
    ).stdout.strip():
        raise RuntimeError("Commit tracked changes before packaging.")
    untracked = run(
        "git",
        "ls-files",
        "--others",
        "--exclude-standard",
        "--",
        "Sources",
        "Tests",
        "Tools",
        "script",
        "Resources",
        "Package.swift",
        "Package.resolved",
        "Makefile",
        capture=True,
    ).stdout
    if untracked.strip():
        raise RuntimeError("Commit maintained source files before packaging.")
    return run("git", "rev-parse", "HEAD", capture=True).stdout.strip()


def create_bundle(directory, binary_directory, version, revision):
    """Package the release executable and its exact runtime resources."""
    app = directory / "Elite.app"
    contents = app / "Contents"
    macos = contents / "MacOS"
    resources = contents / "Resources"
    macos.mkdir(parents=True)
    resources.mkdir()
    shutil.copy2(binary_directory / "Elite", macos / "Elite")
    shutil.copytree(
        binary_directory / "Elite_EliteCore.bundle",
        resources / "Elite_EliteCore.bundle",
    )
    for source, name in [
        ("Resources/Elite.icns", "Elite.icns"),
        ("LICENSE", "LICENSE"),
        ("NOTICE.md", "NOTICE.md"),
    ]:
        shutil.copy2(ROOT / source, resources / name)
    info = {
        "CFBundleExecutable": "Elite",
        "CFBundleIdentifier": "io.xyzzy.elite",
        "CFBundleName": "Elite",
        "CFBundleDisplayName": "XYZZY Elite - Right-On Commander",
        "CFBundlePackageType": "APPL",
        "CFBundleIconFile": "Elite.icns",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": version,
        "LSMinimumSystemVersion": "14.0",
        "NSPrincipalClass": "NSApplication",
        "NSHighResolutionCapable": True,
        "EliteSourceRevision": revision,
    }
    with (contents / "Info.plist").open("wb") as stream:
        plistlib.dump(info, stream)
    return app


def verify_resources(app):
    """Verify every maintained ship, mission and legal resource survived packaging."""
    bundle = app / "Contents/Resources/Elite_EliteCore.bundle"
    if (bundle / "Contents/Resources").is_dir():
        bundle = bundle / "Contents/Resources"
    for source in (ROOT / "Sources/EliteCore/Resources").rglob("*"):
        if not source.is_file():
            continue
        relative = source.relative_to(ROOT / "Sources/EliteCore/Resources")
        target = (
            bundle / relative
            if relative.parts[0] in ["Ships", "MissionPacks"]
            else bundle / source.name
        )
        if not target.is_file() or source.read_bytes() != target.read_bytes():
            raise RuntimeError(f"Missing/changed packaged resource: {relative}")


def package(options):
    """Build, sign, optionally notarize, then verify the extracted deliverable."""
    revision = source_checkpoint()
    scratch = ROOT / ".build/distribution"
    build = [
        "swift",
        "build",
        "--configuration",
        "release",
        "--scratch-path",
        str(scratch),
        "--arch",
        "arm64",
        "--arch",
        "x86_64",
    ]
    run(*build)
    binary_directory = Path(run(*build, "--show-bin-path", capture=True).stdout.strip())
    output = ROOT / "releases/macos"
    output.mkdir(parents=True, exist_ok=True)
    name = f"Elite-{options.version}-universal"
    archive = output / (name + ".zip")
    with tempfile.TemporaryDirectory(
        prefix="elite-package-", dir=ROOT / ".build"
    ) as temporary:
        directory = Path(temporary)
        app = create_bundle(directory, binary_directory, options.version, revision)
        verify_resources(app)
        run(
            "codesign",
            "--force",
            "--timestamp",
            "--sign",
            options.identity,
            str(app / "Contents/Resources/Elite_EliteCore.bundle"),
        )
        run(
            "codesign",
            "--force",
            "--timestamp",
            "--options",
            "runtime",
            "--sign",
            options.identity,
            str(app),
        )
        notarized = False
        if options.notary_profile:
            submission = directory / "submission.zip"
            run(
                "ditto",
                "-c",
                "-k",
                "--sequesterRsrc",
                "--keepParent",
                str(app),
                str(submission),
            )
            run(
                "xcrun",
                "notarytool",
                "submit",
                str(submission),
                "--keychain-profile",
                options.notary_profile,
                "--wait",
            )
            run("xcrun", "stapler", "staple", str(app))
            notarized = True
        run(
            "ditto",
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            str(app),
            str(archive),
        )
        if archive.stat().st_size >= 95 * 1024 * 1024:
            raise RuntimeError(
                "Archive exceeds the repository's 95 MiB packaging limit."
            )
        extracted = directory / "extracted"
        run("ditto", "-x", "-k", str(archive), str(extracted))
        delivered = extracted / "Elite.app"
        run("codesign", "--verify", "--strict", "--deep", "--verbose=2", str(delivered))
        details = run("codesign", "-dvv", str(delivered), capture=True).stderr
        if (
            "Authority=Developer ID Application:" not in details
            or "runtime" not in details
            or "Timestamp=" not in details
        ):
            raise RuntimeError(
                "Expected a timestamped Developer ID signature with hardened runtime."
            )
        architectures = run(
            "lipo", "-archs", str(delivered / "Contents/MacOS/Elite"), capture=True
        ).stdout.split()
        if set(architectures) != {"arm64", "x86_64"}:
            raise RuntimeError("Universal artifact is missing an architecture.")
        build_versions = run(
            "xcrun",
            "vtool",
            "-show-build",
            str(delivered / "Contents/MacOS/Elite"),
            capture=True,
        ).stdout
        minimums = re.findall(r"minos\s+([0-9.]+)", build_versions)
        if minimums != ["14.0", "14.0"]:
            raise RuntimeError("Both executable slices must target macOS 14.0.")
        verify_resources(delivered)
        run(str(delivered / "Contents/MacOS/Elite"), "--diagnostics")
        gatekeeper = run(
            "spctl",
            "--assess",
            "--type",
            "execute",
            "--verbose=2",
            str(delivered),
            capture=True,
            check=False,
        )
        if notarized:
            run("xcrun", "stapler", "validate", str(delivered))
            if gatekeeper.returncode:
                raise RuntimeError(
                    "Notarized artifact did not pass Gatekeeper assessment."
                )
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        (output / (name + ".sha256")).write_text(digest + "  " + archive.name + "\n")
        manifest = {
            "appVersion": options.version,
            "sourceRevision": revision,
            "builtAtUTC": datetime.datetime.now(datetime.UTC).isoformat(),
            "minimumMacOS": "14.0",
            "verifiedMachOMinimums": minimums,
            "architectures": sorted(architectures),
            "archive": archive.name,
            "archiveBytes": archive.stat().st_size,
            "sha256": digest,
            "signature": "Developer ID Application",
            "signatureDetails": [
                "Executable=Elite.app/Contents/MacOS/Elite"
                if line.startswith("Executable=")
                else line
                for line in details.splitlines()
            ],
            "hardenedRuntime": True,
            "secureTimestamp": True,
            "notarized": notarized,
            "gatekeeperAccepted": gatekeeper.returncode == 0,
            "gatekeeperAssessment": (gatekeeper.stdout + gatekeeper.stderr)
            .strip()
            .replace(str(delivered), "Elite.app"),
            "verification": "Extracted ZIP: strict deep signature, architectures, exact resources and diagnostics passed.",
        }
        (output / (name + ".json")).write_text(json.dumps(manifest, indent=2) + "\n")
        print(
            f"Signed package: {archive.relative_to(ROOT)} ({archive.stat().st_size:,} bytes)"
        )
        print(
            f"Source checkpoint: {revision}; notarized: {notarized}; Gatekeeper accepted: {gatekeeper.returncode == 0}"
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default="1.1.0")
    parser.add_argument(
        "--identity",
        default=os.environ.get(
            "ELITE_SIGNING_IDENTITY",
            "Developer ID Application: Steve Clarke (4MEB7MUTAV)",
        ),
    )
    parser.add_argument(
        "--notary-profile", default=os.environ.get("ELITE_NOTARY_PROFILE")
    )
    options = parser.parse_args()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", options.version):
        parser.error("--version must have three numeric components")
    try:
        package(options)
    except (RuntimeError, OSError) as error:
        parser.exit(1, f"Packaging failed: {error}\n")


if __name__ == "__main__":
    main()
