"""Verify only the unchanged, actually published Elite 1.5.0 delivery."""

import hashlib
import json
from pathlib import Path
import urllib.request

from release_version import plan_digest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "ca2e5b2865f808e1d3c4fde4e7f076b6c7a9ce09"
PREFIX = "Elite-1.5.0-universal"
RELEASES = "https://github.com/stephenlclarke/elite/releases/download"
CASK_SHA256 = "adbe08fcac658e682d8b4ddfc238aadf47ac536dccac916bf5243b0d38ea7f72"
PINS = {
    "-notarization.json": "eb72d0c0e698af8977e70a47a67eaa1b8896bf92be3bcc3a9767a29192eedbe1",
    "-release-plan.json": "a4a96fb2fbc8e34dd91031dafe2b2070c70bb5650a4cf79b50f502e4aabc6962",
    ".json": "4822c9286d0bf5cb407cfeb6089bab9de83698995c838c29d72aeba0093cea0f",
    ".sha256": "6602524b58a718ca9db1b592272b624a2013c509947d975763bcbc8415608cf3",
    "-published.json": "52c06ed74dd9e8e772635b4da4a61bfc415502dd1d7da88073a82b8f4d514d6f",
}


def metadata(root: Path = ROOT) -> tuple[dict, dict]:
    """Retain exact public bytes; no historical plan passes through current L337 validation."""
    directory = root / "releases/receipts/Elite-1.5.0"
    data = {}
    for suffix, digest in PINS.items():
        raw = (directory / (PREFIX + suffix)).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError("Historical Elite receipt bytes changed")
        data[suffix] = raw
    manifest, plan, published = (json.loads(data[suffix]) for suffix in
                                 (".json", "-release-plan.json", "-published.json"))
    from homebrew_cask import validate_manifest_properties
    validate_manifest_properties(manifest)
    if (manifest["archive"] != PREFIX + ".zip" or manifest["appVersion"] != "1.5.0"
            or manifest["sourceRevision"] != SOURCE or plan["sourceRevision"] != SOURCE
            or plan["repository"] != "stephenlclarke/elite" or plan["tag"] != "v1.5.0"
            or manifest["releasePlanSha256"] != plan_digest(plan)
            or published["releasePlanSha256"] != plan_digest(plan)
            or published["sourceRevision"] != SOURCE
            or json.loads(data["-notarization.json"])["status"] != "Accepted"
            or data[".sha256"].decode() != f"{manifest['sha256']}  {manifest['archive']}\n"):
        raise ValueError("Historical Elite source, plan or archive join changed")
    assets = {asset["name"]: asset for asset in published["assets"]}
    expected = {PREFIX + suffix for suffix in (".zip", ".sha256", ".json",
                                               "-notarization.json", "-release-plan.json")}
    if set(assets) != expected or len(assets) != len(published["assets"]):
        raise ValueError("Historical Elite asset inventory changed")
    for suffix in (".sha256", ".json", "-notarization.json", "-release-plan.json"):
        asset, raw = assets[PREFIX + suffix], data[suffix]
        if asset["size"] != len(raw) or asset["digest"] != "sha256:" + hashlib.sha256(raw).hexdigest():
            raise ValueError("Historical Elite asset receipt differs from retained bytes")
    archive = assets[PREFIX + ".zip"]
    if archive["size"] != manifest["archiveBytes"] or archive["digest"] != "sha256:" + manifest["sha256"]:
        raise ValueError("Historical Elite archive receipt differs from its manifest")
    return manifest, plan


def verify_historical(cask: Path, download: bool = False, root: Path = ROOT, opener=None) -> None:
    """Check one immutable cask; optional bounded download checks the actual original archive."""
    manifest, _ = metadata(root)
    if hashlib.sha256(cask.read_bytes()).hexdigest() != CASK_SHA256:
        raise ValueError("Historical Elite cask changed")
    if download:
        opener = opener or urllib.request.urlopen
        with opener(f"{RELEASES}/v1.5.0/{PREFIX}.zip", timeout=60) as response:
            archive = response.read(manifest["archiveBytes"] + 1)
        if (len(archive) != manifest["archiveBytes"]
                or hashlib.sha256(archive).hexdigest() != manifest["sha256"]):
            raise ValueError("Historical Elite download differs from its published bytes")
