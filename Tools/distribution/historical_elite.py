"""Verify only the two sealed, actually published Elite 1.5 deliveries."""

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

SOURCE_151 = "e691630ccc3065748d4c02e90eed6a333da0d8b1"
PREFIX_151 = "Elite-1.5.1-universal"
CASK_SHA256_151 = "6497750e52017a69ef998a2e0c91e0c0b7d37c5da60df3728847cff5fe07fb8f"
PINS_151 = {
    "-notarization.json": "377c65ae110953193e5f32d31f95aa74e68240a78dc6cb2ede75068c923c39dc",
    "-release-plan.json": "c464e2995449c413977971320d9d750d2004b6221b031de7f11e218a1e1b2523",
    ".json": "48629bd6733f4593a5b054b32c69a150ebecf136abb17089fa8bb1c0de693951",
    ".sha256": "5dd79724df745a794ace2cd29e65352248f686f17fb5f3e6edde52428d409a68",
    "-published.json": "7f3cd234fa2a5c12a47e80564dfa1e51e141081400cca2dbd3f5a298958f903c",
}


def pinned_release(version: str) -> tuple[str, str, dict]:
    """Select only a retained release; no caller can register another historical version."""
    if version == "1.5.0":
        return SOURCE, PREFIX, PINS
    if version == "1.5.1":
        return SOURCE_151, PREFIX_151, PINS_151
    raise ValueError("Only the two sealed Elite releases can be verified")


def metadata(root: Path = ROOT, version: str = "1.5.0") -> tuple[dict, dict]:
    """Retain exact public bytes; no historical plan passes through current L337 validation."""
    source, prefix, pins = pinned_release(version)
    directory = root / "releases/receipts" / ("Elite-" + version)
    data = {}
    for suffix, digest in pins.items():
        raw = (directory / (prefix + suffix)).read_bytes()
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError("Historical Elite receipt bytes changed")
        data[suffix] = raw
    manifest, plan, published = (json.loads(data[suffix]) for suffix in
                                 (".json", "-release-plan.json", "-published.json"))
    from homebrew_cask import validate_manifest_properties
    validate_manifest_properties(manifest)
    if (manifest["archive"] != prefix + ".zip" or manifest["appVersion"] != version
            or manifest["sourceRevision"] != source or plan["sourceRevision"] != source
            or plan["repository"] != "stephenlclarke/elite" or plan["tag"] != "v" + version
            or manifest["releasePlanSha256"] != plan_digest(plan)
            or published["releasePlanSha256"] != plan_digest(plan)
            or published["sourceRevision"] != source
            or json.loads(data["-notarization.json"])["status"] != "Accepted"
            or data[".sha256"].decode() != f"{manifest['sha256']}  {manifest['archive']}\n"):
        raise ValueError("Historical Elite source, plan or archive join changed")
    assets = {asset["name"]: asset for asset in published["assets"]}
    expected = {prefix + suffix for suffix in (".zip", ".sha256", ".json",
                                               "-notarization.json", "-release-plan.json")}
    if set(assets) != expected or len(assets) != len(published["assets"]):
        raise ValueError("Historical Elite asset inventory changed")
    for suffix in (".sha256", ".json", "-notarization.json", "-release-plan.json"):
        asset, raw = assets[prefix + suffix], data[suffix]
        if asset["size"] != len(raw) or asset["digest"] != "sha256:" + hashlib.sha256(raw).hexdigest():
            raise ValueError("Historical Elite asset receipt differs from retained bytes")
    archive = assets[prefix + ".zip"]
    if archive["size"] != manifest["archiveBytes"] or archive["digest"] != "sha256:" + manifest["sha256"]:
        raise ValueError("Historical Elite archive receipt differs from its manifest")
    return manifest, plan


def verify_historical(cask: Path, download: bool = False, root: Path = ROOT, opener=None) -> None:
    """Check one immutable cask; optional bounded download checks the actual original archive."""
    digest = hashlib.sha256(cask.read_bytes()).hexdigest()
    if digest == CASK_SHA256:
        version = "1.5.0"
    elif digest == CASK_SHA256_151:
        version = "1.5.1"
    else:
        raise ValueError("Historical Elite cask changed")
    manifest, _ = metadata(root, version)
    _, prefix, _ = pinned_release(version)
    if download:
        opener = opener or urllib.request.urlopen
        with opener(f"{RELEASES}/v{version}/{prefix}.zip", timeout=60) as response:
            archive = response.read(manifest["archiveBytes"] + 1)
        if (len(archive) != manifest["archiveBytes"]
                or hashlib.sha256(archive).hexdigest() != manifest["sha256"]):
            raise ValueError("Historical Elite download differs from its published bytes")
