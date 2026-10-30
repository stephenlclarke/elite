#!/usr/bin/env python3
"""Maintain a cask for an already published, signed L337 archive."""

import argparse
import hashlib
import json
import re
import subprocess
import urllib.request
from pathlib import Path

from release_version import (artifact_prefix, load_plan, plan_digest, published_plan,
                             validate_artifact)
ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = "https://raw.githubusercontent.com/stephenlclarke/l337"
RELEASES = "https://github.com/stephenlclarke/l337/releases/download"


def committed_file(revision, path):
    """Read an immutable repository artifact without invoking a shell."""
    return subprocess.run(
        ["git", "show", f"{revision}:{path}"], cwd=ROOT,
        capture_output=True, check=True,
    ).stdout


def validate_manifest(manifest):
    """Require the distributable properties promised by the cask."""
    validate_manifest_properties(manifest)
    if manifest["archive"] != f"L337-{manifest['appVersion']}-universal.zip":
        raise ValueError("Archive name does not match its version.")


def validate_manifest_properties(manifest):
    """Shared signing/platform checks; product identity belongs to the calling verifier."""
    version = manifest["appVersion"]
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("The archive must have a stable three-part version.")
    if not re.fullmatch(r"[a-f0-9]{64}", manifest["sha256"]):
        raise ValueError("The archive requires an exact SHA-256.")
    if manifest["minimumMacOS"] != "14.0":
        raise ValueError("Update the cask OS requirement for this release.")
    if set(manifest["architectures"]) != {"arm64", "x86_64"}:
        raise ValueError("The cask requires both supported architectures.")
    if manifest["signature"] != "Developer ID Application" or not all(
        manifest.get(key) is True for key in
        ("notarized", "gatekeeperAccepted", "hardenedRuntime", "secureTimestamp")
    ):
        raise ValueError("Publish a signed, notarized and verified archive first.")


def release_url(version):
    """Use the separately published, versioned GitHub Release asset."""
    return f"{RELEASES}/v{version}/L337-{version}-universal.zip"


def render_cask(manifest, revision, release_assets=True, source_revision=False):
    """Render the maintained cask from its verified release manifest."""
    validate_manifest(manifest)
    if not re.fullmatch(r"[a-f0-9]{40}", revision):
        raise ValueError("Use the exact protected-main source/artifact commit.")
    if release_assets:
        archive_url = f"{RELEASES}/v#{{version}}/L337-#{{version}}-universal.zip"
        provenance = f"  # {'Source' if source_revision else 'Artifact'} commit: {revision}\n"
        livecheck = '    url :homepage\n    strategy :github_latest'
    else:
        archive_url = f"{REPOSITORY}/{revision}/releases/macos/L337-#{{version}}-universal.zip"
        provenance = ""
        livecheck = '    skip "Published archives are pinned to a reviewed repository commit"'
    return f'''cask "l337" do
  version "{manifest["appVersion"]}"
  sha256 "{manifest["sha256"]}"

{provenance}  url "{archive_url}"
  name "L337"
  desc "Space trading and combat game inspired by BBC Micro Elite"
  homepage "https://github.com/stephenlclarke/l337"

  livecheck do
{livecheck}
  end

  depends_on macos: :sonoma

  app "L337.app"
end
'''


def existing_release(cask):
    """Recover the version and immutable asset commit for a check-only run."""
    version = re.search(r'^  version "([0-9.]+)"$', cask, re.MULTILINE)
    revision = re.search(r"^  # (?:Artifact|Source) commit: ([a-f0-9]{40})$", cask, re.MULTILINE)
    if not revision:
        revision = re.search(re.escape(REPOSITORY) + r"/([a-f0-9]{40})/", cask)
    if not version or not revision:
        raise ValueError("Cannot identify the maintained cask release.")
    return version[1], revision[1]


def public_json(version: str, suffix: str) -> dict:
    url = f"{RELEASES}/v{version}/L337-{version}-universal{suffix}"
    with urllib.request.urlopen(url, timeout=60) as response:
        data = response.read(2 * 1024 * 1024 + 1)
    if len(data) > 2 * 1024 * 1024:
        raise ValueError("Release metadata exceeds its bounded size")
    return json.loads(data)


def planned_release(options: argparse.Namespace, cask: Path) -> tuple[str, str, str]:
    """New updates consume the generated public plan, never an independent version."""
    if options.release_plan:
        local = load_plan(options.release_plan)
        version, revision = local["version"], local["sourceRevision"]
    else:
        version, revision = existing_release(cask.read_text())
        local = None
    plan = public_json(version, "-release-plan.json")
    if local is not None and plan_digest(local) != plan_digest(plan):
        raise ValueError("Public release plan differs from the generated plan")
    # Validate a downloaded plan by the same source/history policy as packaging.
    from release_version import validate_plan
    validate_plan(plan)
    published_plan(plan)
    manifest = public_json(version, ".json")
    validate_manifest(manifest)
    validate_artifact(plan, manifest)
    if plan["version"] != version or plan["sourceRevision"] != revision:
        raise ValueError("Cask and public release identify different source")
    if not options.check or options.verify_download:
        size = manifest["archiveBytes"]
        if type(size) is not int or not 0 < size < 95 * 1024 * 1024:
            raise ValueError("Invalid public archive size")
        with urllib.request.urlopen(release_url(version), timeout=60) as response:
            archive = response.read(size + 1)
        if len(archive) != size or hashlib.sha256(archive).hexdigest() != manifest["sha256"]:
            raise ValueError("Public archive differs from the release plan and manifest")
    return version, revision, render_cask(manifest, revision, source_revision=True)


def main():
    """Check or synchronize the repo/tap copies after verifying their archive."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", help="Historical check only; updates require --release-plan")
    parser.add_argument("--asset-commit", help="Historical check-only artifact commit")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--verify-download", action="store_true")
    parser.add_argument("--tap", type=Path, help="Existing homebrew-tap checkout")
    parser.add_argument("--release-plan", type=Path, help="Generated authoritative release plan")
    options = parser.parse_args()
    cask = ROOT / "Casks/l337.rb"
    # Until a real L337 release exists, verify only the pinned, unchanged Elite 1.5 cask.
    # This path cannot generate a current cask or consume a new-product release plan.
    if options.check and not cask.exists() and not options.release_plan:
        if options.version or options.asset_commit or options.tap:
            parser.error("The closed Elite 1.5 check accepts no alternate version, source or tap.")
        from historical_elite import verify_historical
        verify_historical(ROOT / "Casks/elite.rb", download=options.verify_download)
        print("Historical Elite 1.5.0 cask verified; no L337 publication is implied.")
        return
    planned = options.release_plan or (options.check and "# Source commit:" in cask.read_text())
    if not options.check and not planned:
        parser.error("Cask updates require --release-plan; manual versions are not release inputs.")
    if planned:
        if options.version or options.asset_commit:
            parser.error("Do not mix a generated release plan with manual version inputs.")
        version, revision, expected = planned_release(options, cask)
        paths = [cask]
        if options.tap:
            if not (options.tap / ".git").exists():
                parser.error("--tap must name an existing Git checkout.")
            paths.append(options.tap / "Casks/l337.rb")
        for path in paths:
            if options.check:
                if not path.is_file() or path.read_text() != expected:
                    raise ValueError(f"Cask is out of sync: {path}")
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(expected)
        print(f"L337 {version} cask {'verified' if options.check else 'synchronized'} at {revision}.")
        return
    version, revision = options.version, options.asset_commit
    if options.check and version is None and revision is None:
        version, revision = existing_release(cask.read_text())
    if not version or not revision or not re.fullmatch(r"[a-f0-9]{40}", revision):
        parser.error("Supply --version and an exact --asset-commit, or use --check.")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        parser.error("Invalid stable archive version.")
    relative = f"releases/macos/L337-{version}-universal"
    subprocess.run(
        ["git", "merge-base", "--is-ancestor", revision, "origin/main"],
        cwd=ROOT, check=True,
    )
    manifest = json.loads(committed_file(revision, relative + ".json"))
    if manifest["appVersion"] != version:
        raise ValueError("The committed manifest version does not match its path.")
    legacy = options.check and f'url "{REPOSITORY}/' in cask.read_text()
    expected = render_cask(manifest, revision, release_assets=not legacy)
    archive = committed_file(revision, relative + ".zip")
    if (
        len(archive) != manifest["archiveBytes"]
        or hashlib.sha256(archive).hexdigest() != manifest["sha256"]
    ):
        raise ValueError("Committed archive does not match its release manifest.")
    if options.verify_download or not options.check:
        url = f"{REPOSITORY}/{revision}/{relative}.zip" if legacy else release_url(version)
        with urllib.request.urlopen(url, timeout=60) as response:
            downloaded = response.read()
        if (len(downloaded) != manifest["archiveBytes"]
                or hashlib.sha256(downloaded).hexdigest() != manifest["sha256"]):
            raise ValueError("The public download does not match the release manifest.")
    paths = [cask]
    if options.tap:
        if not (options.tap / ".git").exists():
            parser.error("--tap must name an existing Git checkout.")
        paths.append(options.tap / "Casks/l337.rb")
    for path in paths:
        if options.check:
            if not path.is_file() or path.read_text() != expected:
                raise ValueError(f"Cask is out of sync: {path}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(expected)
    action = "verified" if options.check else "synchronized"
    print(f"L337 {version} cask {action} at {revision}.")


if __name__ == "__main__":
    main()
