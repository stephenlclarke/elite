#!/usr/bin/env python3
"""Verify the authoritative branch and previous-version new-code baseline."""
import json
import os
import urllib.request


def read(endpoint):
    """Read settings without placing credentials in process arguments or logs."""
    request = urllib.request.Request(
        "https://sonarcloud.io/api/" + endpoint,
        headers={"Authorization": "Bearer " + os.environ["SONAR_TOKEN"]},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def main():
    """Fail closed if the remote project settings have drifted."""
    settings = read("settings/values?component=stephenlclarke_elite&keys=sonar.leak.period")
    assert any(s["key"] == "sonar.leak.period" and s.get("value") == "previous_version"
               for s in settings["settings"]), "Set new code to Previous version"
    branches = read("project_branches/list?project=stephenlclarke_elite")
    assert [b["name"] for b in branches["branches"] if b["isMain"]] == ["main"], "Sonar main branch must be main"
    print("Sonar settings verified: main, Previous version")


if __name__ == "__main__":
    main()
