#!/usr/bin/env python3
"""Read-only README release-link reachability; never distribution trust or installation proof."""
import argparse
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request

from homebrew_cask import RELEASES, release_url

OFFICIAL_HOSTS = {
    "github.com", "api.github.com", "raw.githubusercontent.com",
    "release-assets.githubusercontent.com", "objects.githubusercontent.com",
    "github-releases.githubusercontent.com",
}
VERSION = r"[0-9]+\.[0-9]+\.[0-9]+"
ARCHIVE = r"[^/]+\.(?:zip|dmg|pkg|tgz|tar\.gz)"


class Anchors(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links, self.active = [], None

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.active = [dict(attrs).get("href", ""), ""]

    def handle_data(self, data):
        if self.active is not None:
            self.active[1] += data

    def handle_endtag(self, tag):
        if tag == "a" and self.active is not None:
            self.links.append(tuple(self.active))
            self.active = None


def prose(readme):
    readme = re.sub(r"<!--[\s\S]*?-->", "", readme)
    lines, fence, list_indents = [], None, []
    paragraph, indented_code = False, False
    for original in readme.splitlines():
        line = original.expandtabs(4)
        indent = len(line) - len(line.lstrip(" "))
        body = line[indent:]
        if fence is not None:
            if re.fullmatch(re.escape(fence[0]) + "{" + str(len(fence)) + r",}\s*", body):
                fence = None
            continue
        if not body:
            paragraph = False
            lines.append("")
            continue
        while list_indents and indent < list_indents[-1]:
            list_indents.pop()
        base = list_indents[-1] if list_indents else 0
        if indented_code:
            if indent >= base + 4:
                continue
            indented_code = False
        # Indented code cannot interrupt an existing paragraph. List continuation
        # prose is relative to the marker's content column, not the document edge.
        if not paragraph and indent >= base + 4:
            indented_code = True
            continue
        item = re.match(r"^([-+*]|[0-9]+[.)])( +)(.*)$", body)
        if item and indent < base + 4:
            padding = len(item[2])
            content_indent = indent + len(item[1]) + min(padding, 1 if padding > 4 else padding)
            list_indents.append(content_indent)
            body = item[3]
            if padding > 4 and body:
                indented_code, paragraph = True, False
                continue
        marker = re.match(r"^(`{3,}|~{3,})", body)
        if marker and indent < base + 4:
            fence, paragraph = marker[1], False
            continue
        lines.append(line)
        paragraph = bool(body)
    return re.sub(r"(`+)(.*?)\1", "", "\n".join(lines), flags=re.DOTALL)


def classify(url, repo):
    parts = urllib.parse.urlsplit(url)
    path = urllib.parse.unquote(parts.path)
    prefix = "/" + repo + "/releases/"
    if parts.hostname == "github.com" and path.startswith(prefix):
        suffix = path[len(prefix):]
        if suffix == "latest":
            return {"kind": "latest_release", "sourceVersion": None, "asset": None}
        match = re.fullmatch(r"tag/v?(" + VERSION + r")", suffix)
        if match:
            return {"kind": "versioned_release", "sourceVersion": match[1], "asset": None}
        match = re.fullmatch(r"download/v?(" + VERSION + r")/(" + ARCHIVE + r")", suffix)
        if match:
            return {"kind": "archive", "sourceVersion": match[1], "asset": match[2]}
        match = re.fullmatch(r"latest/download/(" + ARCHIVE + r")", suffix)
        if match:
            return {"kind": "latest_archive", "sourceVersion": None, "asset": match[1]}
    if parts.hostname == "raw.githubusercontent.com":
        match = re.fullmatch("/" + re.escape(repo) + r"/[a-f0-9]{40}/releases/macos/(" + ARCHIVE + r")", path)
        if match:
            version = re.search(r"-(" + VERSION + r")(?:-|\.)", match[1])
            return {"kind": "historical_raw_archive", "sourceVersion": version[1] if version else None, "asset": match[1]}
    return None


def links(readme, repo, maximum=12):
    content = prose(readme)
    parser = Anchors()
    parser.feed(content)
    candidates = list(parser.links)
    candidates += [(html.unescape(url.strip("<>")), label) for label, url in re.findall(r"(?<!!)\[([^\]\n]+)\]\(\s*(<?https?://[^\s)>]+>?)\s*(?:\"[^\"]*\")?\)", content)]
    definitions = {key.lower(): url.strip("<>") for key, url in re.findall(r"^\s*\[([^\]]+)\]:\s*(<?https?://[^\s>]+>?)", content, re.MULTILINE)}
    for label, key in re.findall(r"(?<!!)\[([^\]]+)\]\[([^\]]*)\]", content):
        if (key or label).lower() in definitions:
            candidates.append((definitions[(key or label).lower()], label))
    candidates += [(url, "") for url in re.findall(r"<(https?://[^\s>]+)>", content)]
    found = {}
    for url, label in candidates:
        info = classify(url, repo)
        if info is None:
            continue
        if url not in found:
            found[url] = {"url": url, **info, "labels": [], "recommendedLatest": info["kind"].startswith("latest_")}
        found[url]["labels"].append(label)
        if re.search(r"\b(latest|newest|current release)\b", label, re.IGNORECASE):
            found[url]["recommendedLatest"] = True
    if len(found) > maximum:
        raise ValueError("README release links exceed the bounded request budget")
    return list(found.values())


def official(url):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or parsed.hostname not in OFFICIAL_HOSTS or parsed.username or parsed.password or parsed.port not in (None, 443):
        raise ValueError("Refused nonofficial/non-HTTPS/credentialled URL")
    return url


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def public_url(url):
    parsed = urllib.parse.urlsplit(url)
    host = parsed.hostname or ""
    if parsed.port not in (None, 443):
        host += ":" + str(parsed.port)
    return urllib.parse.urlunsplit((parsed.scheme, host, parsed.path, "", ""))


def request(url, method="HEAD", one_byte=False, json_limit=0, opener=None):
    """Follow only bounded official HTTPS redirects; never drain a redirect/app body."""
    opener = opener or urllib.request.build_opener(NoRedirect())
    for _ in range(6):
        official(url)
        headers = {"User-Agent": "L337-read-only-README-link-check"}
        if one_byte:
            headers["Range"] = "bytes=0-0"
        req = urllib.request.Request(url, method=method, headers=headers)
        try:
            response = opener.open(req, timeout=10)
        except urllib.error.HTTPError as error:
            status, location = error.code, error.headers.get("Location")
            error.close()
            if status in (301, 302, 303, 307, 308) and location:
                url = urllib.parse.urljoin(url, location)
                continue
            return {"httpStatus": status, "finalURL": public_url(url), "body": b""}
        try:
            body = response.read(1) if one_byte else response.read(json_limit + 1) if json_limit else b""
            if json_limit and len(body) > json_limit:
                raise ValueError("Public release metadata exceeds bounded size")
            return {"httpStatus": response.status, "finalURL": public_url(url), "body": body}
        finally:
            response.close()
    raise ValueError("Too many release URL redirects")


def probe(url, requester=request):
    try:
        # Initial README queries are unnecessary for public release/archive endpoints.
        if urllib.parse.urlsplit(url).query:
            raise ValueError("Refused queried initial README URL")
        response = requester(url)
        fallback = response["httpStatus"] in (405, 501)
        if fallback:
            response = requester(url, method="GET", one_byte=True)
        status = response["httpStatus"]
        state = "reachable" if 200 <= status < 300 else "broken" if status in (404, 410) else "inconclusive"
        return {"state": state, "httpStatus": status, "finalURL": response["finalURL"], "rangeFallback": fallback, "archiveBodyBytesRead": len(response["body"])}
    except (OSError, ValueError, urllib.error.URLError) as error:
        return {"state": "inconclusive", "reason": str(error)}


def latest(repo, requester=request):
    try:
        response = requester(f"https://api.github.com/repos/{repo}/releases/latest", method="GET", json_limit=262144)
        if response["httpStatus"] != 200:
            return {"state": "inconclusive", "httpStatus": response["httpStatus"]}
        data = json.loads(response["body"])
        tag = data.get("tag_name", "")
        if not re.fullmatch("v?" + VERSION, tag) or data.get("draft") or data.get("prerelease"):
            return {"state": "inconclusive", "reason": "No stable published version established"}
        assets = data.get("assets", [])
        if len(assets) > 256:
            raise ValueError("Too many published assets")
        return {"state": "published", "version": tag.removeprefix("v"), "assets": [a["name"] for a in assets], "metadataURL": f"https://api.github.com/repos/{repo}/releases/latest"}
    except (OSError, ValueError, KeyError, TypeError, urllib.error.URLError) as error:
        return {"state": "inconclusive", "reason": str(error)}


def check(readme, repo, expected=None, fetch_latest=False, requester=request):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo) or any(p in (".", "..") for p in repo.split("/")):
        raise ValueError("Invalid public repository identity")
    if expected and not re.fullmatch(VERSION, expected):
        raise ValueError("Expected version must be stable X.Y.Z")
    published = latest(repo, requester) if fetch_latest else {"state": "not_requested"}
    current = published.get("version") or expected
    records = []
    for record in links(readme, repo):
        original_url = record["url"]
        record.update(probe(original_url, requester))
        record["url"] = public_url(original_url)
        source = record["sourceVersion"]
        record["versionRelationship"] = "latest_recommendation" if source is None and record["recommendedLatest"] else "current" if source and source == current else "historical_or_different" if source and current else "not_established"
        record["staleLatestRecommendation"] = bool(record["recommendedLatest"] and source and current and source != current)
        records.append(record)
    states = [r["state"] for r in records]
    overall = "BROKEN_LINKS" if "broken" in states else "INCONCLUSIVE" if "inconclusive" in states or fetch_latest and published["state"] != "published" else "REACHABLE" if states else "NO_RELEASE_LINKS"
    native_repo = urllib.parse.urlsplit(RELEASES).path.removesuffix("/releases/download").strip("/")
    expected_link = release_url(expected) if expected and repo == native_repo else None
    if repo == "stephenlclarke/elite" and expected == "1.5.0":
        from historical_elite import PREFIX, RELEASES as historical_releases
        expected_link = f"{historical_releases}/v1.5.0/{PREFIX}.zip"
    return {"state": overall, "repository": repo, "expectedPublishedVersion": expected,
            "published": published, "expectedAssetURLFromExistingCaskHelper": expected_link,
            "expectedVersionDiffersFromPublicMetadata": bool(expected and published.get("version") and expected != published["version"]),
            "links": records, "limits": "Reachability/version metadata is NOT signature, checksum, notarization, installation or Homebrew readiness proof. No app execution or full download. HTTP 403/429 and network failures remain inconclusive."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--readme", type=Path, required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--expected-version")
    parser.add_argument("--latest-metadata", action="store_true")
    args = parser.parse_args()
    try:
        with args.readme.open("rb") as stream:
            raw = stream.read(2097153)
        if len(raw) > 2097152:
            raise ValueError("README exceeds 2 MiB")
        result = check(raw.decode(), args.repo, args.expected_version, args.latest_metadata)
        print(json.dumps(result, indent=2))
        return 1 if result["state"] == "BROKEN_LINKS" else 2 if result["state"] in ("INCONCLUSIVE", "NO_RELEASE_LINKS") else 0
    except (OSError, ValueError) as error:
        parser.exit(2, str(error) + "\n")


if __name__ == "__main__":
    raise SystemExit(main())
