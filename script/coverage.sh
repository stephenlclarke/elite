#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Main analysis and make ci qualify the same complete, identity-bound phase.
exec python3 Tools/CI/quality_phase_checkpoints.py normal
