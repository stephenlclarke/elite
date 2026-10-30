#!/usr/bin/env python3
"""Generate the single source-bound release version from published Conventional history."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REPO = "stephenlclarke/l337"
POLICY = "conventional-nonmerge-max-impact-v1"
VERSION = r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
HEADER = re.compile(r"^([a-z][a-z0-9-]*)(?:\([^\n)]+\))?(!)?: \S[^\n]*$")


def command(*args: str, root: Path = ROOT) -> str:
    return subprocess.check_output(args, cwd=root, text=True).strip()


def github(path: str) -> dict:
    return json.loads(command("gh", "api", f"repos/{REPO}/{path}"))


def tag_revision(tag: str) -> str:
    reference = github("git/ref/tags/" + tag)["object"]
    for _ in range(8):
        if reference["type"] == "commit":
            return reference["sha"]
        if reference["type"] != "tag":
            break
        reference = github("git/tags/" + reference["sha"])["object"]
    raise ValueError("Release tag does not resolve to a commit")


def semver(value: str) -> tuple[int, int, int]:
    match = re.fullmatch(VERSION, value)
    if not match:
        raise ValueError("Use a stable, canonical three-part semantic version")
    return tuple(int(part) for part in match.groups())


def impact(message: str) -> str:
    header = message.splitlines()[0] if message else ""
    match = HEADER.fullmatch(header)
    if not match:
        raise ValueError("Every non-merge release commit must use Conventional Commits")
    if (re.search(r"^BREAKING[ -]CHANGE:", message, re.MULTILINE)
            and not re.search(r"^BREAKING[ -]CHANGE: +\S", message, re.MULTILINE)):
        raise ValueError("A breaking-change footer requires a description")
    if match[2] or re.search(r"^BREAKING[ -]CHANGE: +\S", message, re.MULTILINE):
        return "major"
    return {"feat": "minor", "fix": "patch", "perf": "patch"}.get(match[1], "none")


def history(base: str, head: str, root: Path = ROOT) -> list[dict[str, str]]:
    # Traverse the whole DAG once. Real merge commits are excluded; their child
    # commits remain present. Squash commits are ordinary non-merge commits.
    raw = command("git", "log", "--no-merges", "--format=%H%x00%B%x00", f"{base}..{head}", root=root)
    parts = raw.split("\0")
    records = []
    for index in range(0, len(parts) - 1, 2):
        sha, message = parts[index].strip(), parts[index + 1].strip()
        if not re.fullmatch(r"[a-f0-9]{40}", sha):
            raise ValueError("Invalid commit identity in release history")
        try:
            change = impact(message)
        except ValueError as error:
            raise ValueError(f"Commit {sha} is not conventional") from error
        records.append({"sha": sha, "subject": message.splitlines()[0], "impact": change})
    return sorted(records, key=lambda record: record["sha"])


def make_plan(base_tag: str, base_sha: str, head: str, records: list[dict[str, str]], authoritative: bool) -> dict:
    base = semver(base_tag.removeprefix("v"))
    rank = {"none": 0, "patch": 1, "minor": 2, "major": 3}
    change = max((record["impact"] for record in records), key=rank.get, default="none")
    major, minor, patch = base
    next_version = {
        "major": (major + 1, 0, 0), "minor": (major, minor + 1, 0),
        "patch": (major, minor, patch + 1), "none": None,
    }[change]
    version = ".".join(map(str, next_version)) if next_version else None
    return {"schema": 1, "repository": REPO, "policy": POLICY,
            "baseTag": base_tag, "baseRevision": base_sha, "sourceRevision": head,
            "impact": change, "releaseRequired": version is not None,
            "version": version, "tag": "v" + version if version else None,
            "authoritative": authoritative, "commits": records,
            "historySha256": hashlib.sha256(json.dumps(records, sort_keys=True).encode()).hexdigest()}


def plan_digest(plan: dict) -> str:
    return hashlib.sha256(json.dumps(plan, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def latest_published_ancestor(releases: list[dict], head: str, root: Path = ROOT) -> tuple[str, str]:
    candidates = []
    for release in releases:
        if release["draft"] or release["prerelease"]:
            continue
        tag = release["tag_name"]
        try:
            version = semver(tag.removeprefix("v"))
        except ValueError:
            continue
        sha = command("git", "rev-parse", tag + "^{commit}", root=root)
        result = subprocess.run(["git", "merge-base", "--is-ancestor", sha, head], cwd=root)
        if result.returncode == 0:
            candidates.append((version, tag, sha))
        elif result.returncode != 1:
            raise ValueError("Cannot establish released-tag ancestry")
    if not candidates:
        raise ValueError("No published stable ancestor release exists")
    _, tag, sha = max(candidates)
    return tag, sha


def require_main(head: str) -> None:
    if github("git/ref/heads/main")["object"]["sha"] != head:
        raise ValueError("Authoritative releases require the current protected main commit")


def generate(preview: bool = False, root: Path = ROOT) -> dict:
    if command("git", "status", "--porcelain", root=root):
        raise ValueError("Commit the source before generating a release plan")
    head = command("git", "rev-parse", "HEAD", root=root)
    if not preview:
        require_main(head)
    command("git", "fetch", "origin", "--tags", root=root)
    pages = json.loads(command("gh", "api", f"repos/{REPO}/releases", "--paginate", "--slurp", root=root))
    releases = [release for page in pages for release in page]
    tag, base_sha = latest_published_ancestor(releases, head, root)
    plan = make_plan(tag, base_sha, head, history(base_sha, head, root), not preview)
    if plan["releaseRequired"]:
        existing = subprocess.run(["git", "show-ref", "--verify", "--quiet", "refs/tags/" + plan["tag"]], cwd=root)
        if existing.returncode == 0 or any(release["tag_name"] == plan["tag"] for release in releases):
            raise ValueError("Calculated release tag already exists; do not overwrite it")
        if existing.returncode != 1:
            raise ValueError("Cannot check release-tag availability")
    return plan


def validate_plan(plan: dict, root: Path = ROOT, current: bool = False) -> dict:
    if (not isinstance(plan, dict) or plan.get("repository") != REPO
            or type(plan.get("schema")) is not int
            or not isinstance(plan.get("authoritative"), bool)
            or not isinstance(plan.get("baseTag"), str)
            or not re.fullmatch("v?" + VERSION, plan["baseTag"])):
        raise ValueError("Invalid release plan")
    for field in ("baseRevision", "sourceRevision"):
        if not isinstance(plan.get(field), str) or not re.fullmatch(r"[a-f0-9]{40}", plan[field]):
            raise ValueError("Release revisions must be exact commit identities")
    if command("git", "rev-parse", plan["baseTag"] + "^{commit}", root=root) != plan["baseRevision"]:
        raise ValueError("Released base tag changed")
    subprocess.run(["git", "merge-base", "--is-ancestor", plan["baseRevision"], plan["sourceRevision"]],
                   cwd=root, check=True, capture_output=True)
    expected = make_plan(plan["baseTag"], plan["baseRevision"], plan["sourceRevision"],
                         history(plan["baseRevision"], plan["sourceRevision"], root), plan["authoritative"])
    if plan != expected:
        raise ValueError("Release plan does not match its Conventional Commit history")
    if not plan["authoritative"] or not plan["releaseRequired"]:
        raise ValueError("A preview or documentation-only plan cannot publish a release")
    base = github("releases/tags/" + plan["baseTag"])
    if base["draft"] or base["prerelease"] or base["tag_name"] != plan["baseTag"]:
        raise ValueError("The base must be an actually published stable release")
    if tag_revision(plan["baseTag"]) != plan["baseRevision"]:
        raise ValueError("Published base tag differs from recorded history")
    if current:
        if command("git", "status", "--porcelain", root=root):
            raise ValueError("Release packaging/publication requires a clean committed checkout")
        if command("git", "rev-parse", "HEAD", root=root) != plan["sourceRevision"]:
            raise ValueError("Release plan source differs from the current checkout")
        require_main(plan["sourceRevision"])
    return plan


def load_plan(path: Path, current: bool = False, root: Path = ROOT) -> dict:
    return validate_plan(json.loads(Path(path).read_text()), root, current)


def artifact_prefix(plan: dict) -> str:
    return f"L337-{plan['version']}-universal"


def validate_artifact(plan: dict, manifest: dict) -> None:
    if (manifest.get("appVersion") != plan["version"]
            or manifest.get("sourceRevision") != plan["sourceRevision"]
            or manifest.get("archive") != artifact_prefix(plan) + ".zip"
            or manifest.get("releasePlanSha256") != plan_digest(plan)):
        raise ValueError("Artifact version/source does not match the generated release plan")


def published_plan(plan: dict) -> dict:
    release = github("releases/tags/" + plan["tag"])
    if release["draft"] or release["prerelease"] or release["tag_name"] != plan["tag"]:
        raise ValueError("The generated release is not publicly published")
    if tag_revision(plan["tag"]) != plan["sourceRevision"]:
        raise ValueError("Published tag does not identify the exact release source")
    return release


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist/release-plan.json")
    parser.add_argument("--preview", action="store_true", help="Calculate on a committed branch; never package or publish")
    args = parser.parse_args()
    plan = generate(args.preview)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(plan, indent=2) + "\n")
    print(json.dumps({key: plan[key] for key in ("baseTag", "sourceRevision", "impact", "version", "authoritative")}))


if __name__ == "__main__":
    main()
