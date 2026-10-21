#!/usr/bin/env python3
"""Maintain a cask for an already published, signed Elite archive."""

import argparse
import hashlib
import json
import re
import subprocess
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = "https://raw.githubusercontent.com/stephenlclarke/elite"
RELEASES = "https://github.com/stephenlclarke/elite/releases/download"


def committed_file(revision, path):
    """Read an immutable repository artifact without invoking a shell."""
    return subprocess.run(
        ["git", "show", f"{revision}:{path}"], cwd=ROOT,
        capture_output=True, check=True,
    ).stdout


def validate_manifest(manifest):
    """Require the distributable properties promised by the cask."""
    version = manifest["appVersion"]
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("The archive must have a stable three-part version.")
    if manifest["archive"] != f"Elite-{version}-universal.zip":
        raise ValueError("Archive name does not match its version.")
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
    return f"{RELEASES}/v{version}/Elite-{version}-universal.zip"


def render_cask(manifest, revision, release_assets=True):
    """Render the maintained cask from the committed release manifest."""
    validate_manifest(manifest)
    if not re.fullmatch(r"[a-f0-9]{40}", revision):
        raise ValueError("Use the exact commit containing the published ZIP.")
    if release_assets:
        archive_url = f"{RELEASES}/v#{{version}}/Elite-#{{version}}-universal.zip"
        provenance = f"  # Artifact commit: {revision}\n"
        livecheck = '    url :homepage\n    strategy :github_latest'
    else:
        archive_url = f"{REPOSITORY}/{revision}/releases/macos/Elite-#{{version}}-universal.zip"
        provenance = ""
        livecheck = '    skip "Published archives are pinned to a reviewed repository commit"'
    return f'''cask "elite" do
  version "{manifest["appVersion"]}"
  sha256 "{manifest["sha256"]}"

{provenance}  url "{archive_url}"
  name "Elite"
  desc "Space trading and combat game inspired by BBC Micro Elite"
  homepage "https://github.com/stephenlclarke/elite"

  livecheck do
{livecheck}
  end

  depends_on macos: :sonoma

  app "Elite.app"
end
'''


def existing_release(cask):
    """Recover the version and immutable asset commit for a check-only run."""
    version = re.search(r'^  version "([0-9.]+)"$', cask, re.MULTILINE)
    revision = re.search(r"^  # Artifact commit: ([a-f0-9]{40})$", cask, re.MULTILINE)
    if not revision:
        revision = re.search(re.escape(REPOSITORY) + r"/([a-f0-9]{40})/", cask)
    if not version or not revision:
        raise ValueError("Cannot identify the maintained cask release.")
    return version[1], revision[1]


def main():
    """Check or synchronize the repo/tap copies after verifying their archive."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", help="Already published archive version")
    parser.add_argument("--asset-commit", help="Exact commit containing its ZIP")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--verify-download", action="store_true")
    parser.add_argument("--tap", type=Path, help="Existing homebrew-tap checkout")
    options = parser.parse_args()
    cask = ROOT / "Casks/elite.rb"
    version, revision = options.version, options.asset_commit
    if options.check and version is None and revision is None:
        version, revision = existing_release(cask.read_text())
    if not version or not revision or not re.fullmatch(r"[a-f0-9]{40}", revision):
        parser.error("Supply --version and an exact --asset-commit, or use --check.")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        parser.error("Invalid stable archive version.")
    relative = f"releases/macos/Elite-{version}-universal"
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
        paths.append(options.tap / "Casks/elite.rb")
    for path in paths:
        if options.check:
            if not path.is_file() or path.read_text() != expected:
                raise ValueError(f"Cask is out of sync: {path}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(expected)
    action = "verified" if options.check else "synchronized"
    print(f"Elite {version} cask {action} at {revision}.")


if __name__ == "__main__":
    main()
