#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(git branch --show-current)" == main ]] || { printf 'Authoritative Sonar analysis must run on main.\n' >&2; exit 2; }
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { printf 'Commit changes before authoritative analysis.\n' >&2; exit 2; }
export SONAR_TOKEN="${SONAR_TOKEN:-${SONAR_TOKEN_PERSONAL:-}}"
[[ -n "$SONAR_TOKEN" ]] || { printf 'SONAR_TOKEN is required.\n' >&2; exit 2; }
python3 Tools/verify-sonar-settings.py
./script/coverage.sh
sonar-scanner -Dsonar.projectVersion="$(git rev-parse HEAD)"
