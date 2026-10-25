#!/usr/bin/env python3
"""Publish and document verified artifacts using their single generated release plan."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from homebrew_cask import validate_manifest
from release_version import (ROOT, REPO, artifact_prefix, command, github, load_plan,
                             plan_digest, published_plan, require_main, tag_revision)
from release_version import validate_artifact


def file_digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def artifacts(plan: dict, root: Path = ROOT) -> dict[str, Path]:
    prefix = artifact_prefix(plan)
    return {prefix + suffix: root / "dist/macos" / (prefix + suffix)
            for suffix in (".zip", ".sha256", ".json", "-notarization.json", "-release-plan.json")}


def verify_local(plan: dict, root: Path = ROOT) -> dict[str, Path]:
    files = artifacts(plan, root)
    prefix = artifact_prefix(plan)
    manifest = json.loads(files[prefix + ".json"].read_text())
    validate_manifest(manifest)
    validate_artifact(plan, manifest)
    archive = files[prefix + ".zip"]
    if archive.stat().st_size != manifest["archiveBytes"] or file_digest(archive) != manifest["sha256"]:
        raise ValueError("Release archive does not match its signed manifest")
    if files[prefix + ".sha256"].read_text() != f"{manifest['sha256']}  {archive.name}\n":
        raise ValueError("Release checksum differs from the generated archive")
    if json.loads(files[prefix + "-release-plan.json"].read_text()) != plan:
        raise ValueError("Packaged release plan differs from the authoritative plan")
    if json.loads(files[prefix + "-notarization.json"].read_text()).get("status") != "Accepted":
        raise ValueError("The release requires Apple's accepted notarization report")
    return files


def verify_assets(release: dict, files: dict[str, Path]) -> None:
    assets = {asset["name"]: asset for asset in release["assets"]}
    if set(assets) != set(files) or len(assets) != len(release["assets"]):
        raise ValueError("Published asset inventory is incomplete or unexpected")
    for name, path in files.items():
        asset = assets[name]
        if (asset["state"] != "uploaded" or asset["size"] != path.stat().st_size
                or asset.get("digest") != "sha256:" + file_digest(path)):
            raise ValueError("Uploaded release bytes differ from the verified local artifact")


def optional_github(path: str) -> dict | None:
    result = subprocess.run(["gh", "api", f"repos/{REPO}/{path}"],
                            capture_output=True, text=True, cwd=ROOT)
    payload = json.loads(result.stdout)
    if result.returncode and str(payload.get("status")) == "404":
        return None
    if result.returncode:
        raise ValueError("Cannot read GitHub release state")
    return payload


def publish(plan: dict, root: Path = ROOT) -> dict:
    require_main(plan["sourceRevision"])
    checks = github(f"commits/{plan['sourceRevision']}/check-runs")["check_runs"]
    quality = [check for check in checks if check["name"] == "quality"
               and check["head_sha"] == plan["sourceRevision"] and check["app"]["id"] == 15368]
    if not quality or max(quality, key=lambda check: check["id"])["conclusion"] != "success":
        raise ValueError("The exact main source must pass required quality and main analysis first")
    files = verify_local(plan, root)
    # A failed upload remains a draft. No published-success receipt is written
    # until every immutable asset and the exact tag target have been verified.
    existing = optional_github("releases/tags/" + plan["tag"])
    if existing is not None and (existing["tag_name"] != plan["tag"]
                                 or existing["target_commitish"] != plan["sourceRevision"]):
        raise ValueError("An existing release belongs to different source")
    reference = optional_github("git/ref/tags/" + plan["tag"])
    if reference is None:
        command("gh", "api", f"repos/{REPO}/git/refs", "-f", "ref=refs/tags/" + plan["tag"],
                "-f", "sha=" + plan["sourceRevision"], root=root)
    elif tag_revision(plan["tag"]) != plan["sourceRevision"]:
        raise ValueError("Never overwrite an existing release tag")
    if existing is None:
        command("gh", "release", "create", plan["tag"], *map(str, files.values()),
                "--repo", REPO, "--target", plan["sourceRevision"], "--verify-tag", "--draft",
                "--title", "Elite " + plan["version"], "--generate-notes",
                "--notes-start-tag", plan["baseTag"], root=root)
    elif existing["draft"]:
        present = {asset["name"] for asset in existing["assets"]}
        if not present <= set(files):
            raise ValueError("Draft contains unexpected assets")
        verify_assets(existing, {name: path for name, path in files.items() if name in present})
        missing = [str(path) for name, path in files.items() if name not in present]
        if missing:
            command("gh", "release", "upload", plan["tag"], "--repo", REPO, *missing, root=root)
    draft = github("releases/tags/" + plan["tag"])
    if tag_revision(plan["tag"]) != plan["sourceRevision"]:
        raise ValueError("Draft release tag differs from the planned source")
    verify_assets(draft, files)
    if draft["draft"]:
        command("gh", "release", "edit", plan["tag"], "--repo", REPO, "--draft=false", root=root)
    released = published_plan(plan)
    verify_assets(released, files)
    receipt = {"version": plan["version"], "tag": plan["tag"],
               "sourceRevision": plan["sourceRevision"], "releasePlanSha256": plan_digest(plan),
               "releaseURL": released["html_url"], "assets": [
                   {key: asset[key] for key in ("name", "size", "digest", "browser_download_url")}
                   for asset in released["assets"]]}
    (root / "dist/macos" / (artifact_prefix(plan) + "-published.json")).write_text(json.dumps(receipt, indent=2) + "\n")
    return receipt


def readme_text(text: str, plan: dict, manifest: dict) -> str:
    validate_artifact(plan, manifest)
    import re
    block = ("<!-- current-release:start -->\n"
             f"The latest signed release is [Elite {plan['version']}](https://github.com/{REPO}/releases/tag/{plan['tag']}). "
             f"Its [universal Mac download](https://github.com/{REPO}/releases/download/{plan['tag']}/{manifest['archive']}) "
             "includes the matching checksum, signing manifest, release plan and Apple notarization report. "
             "The Homebrew badge links to the actual published tap cask; tap updates pass review separately.\n"
             "<!-- current-release:end -->")
    pattern = r"<!-- current-release:start -->[\s\S]*?<!-- current-release:end -->"
    if re.search(pattern, text):
        return re.sub(pattern, lambda _: block, text, count=1)
    old = r"^The \[published tap cask\].*$"
    if len(re.findall(old, text, re.MULTILINE)) != 1:
        raise ValueError("Cannot identify the README's current release paragraph")
    return re.sub(old, lambda _: block, text, count=1, flags=re.MULTILINE)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("publish", "readme"))
    parser.add_argument("--release-plan", type=Path, default=ROOT / "dist/release-plan.json")
    args = parser.parse_args()
    plan = load_plan(args.release_plan, current=args.action == "publish")
    if args.action == "publish":
        print(json.dumps(publish(plan)))
    else:
        released = published_plan(plan)
        files = verify_local(plan)
        verify_assets(released, files)
        manifest = json.loads(files[artifact_prefix(plan) + ".json"].read_text())
        path = ROOT / "README.md"
        path.write_text(readme_text(path.read_text(), plan, manifest))
        print("README links updated to verified published release " + plan["version"])


if __name__ == "__main__":
    main()
