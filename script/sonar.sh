#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Authoritative analysis is restricted to the committed main branch.
require_main() {
  [[ "$(git branch --show-current)" == main ]] || {
    printf 'Authoritative Sonar analysis must run on main.\n' >&2
    exit 2
  }
}

# Reuse the distribution guard, including untracked maintained source checks.
source_checkpoint() {
  python3 -c 'from Tools.distribution.package_macos import source_checkpoint; print(source_checkpoint("authoritative analysis"))'
}

require_main
SOURCE_REVISION="$(source_checkpoint)"
readonly SOURCE_REVISION
[[ "$SOURCE_REVISION" =~ ^[0-9a-f]{40}$ ]] || {
  printf 'Authoritative Sonar analysis requires a lowercase 40-character commit SHA.\n' >&2
  exit 2
}
export SONAR_TOKEN="${SONAR_TOKEN:-${SONAR_TOKEN_PERSONAL:-}}"
[[ -n "$SONAR_TOKEN" ]] || { printf 'SONAR_TOKEN is required.\n' >&2; exit 2; }
python3 Tools/verify-sonar-settings.py
./script/coverage.sh
require_main
CURRENT_REVISION="$(source_checkpoint)"
[[ "$CURRENT_REVISION" == "$SOURCE_REVISION" ]] || {
  printf 'Source checkpoint changed during coverage; do not publish this analysis.\n' >&2
  exit 2
}
sonar-scanner -Dsonar.projectVersion="$SOURCE_REVISION"
