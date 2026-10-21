# Review dependency updates continuously

## Motivation

The repository pins TOMLDecoder 0.4.5 and its GitHub Actions but has no Dependabot version-update configuration or PR dependency-review workflow. The user requested daily dependency maintenance and truthful README badges. Existing GitHub dependency graph, Dependabot alerts and security updates are enabled; these settings do not prove that every dependency is represented or vulnerability-free.

## Acceptance

Schedule daily Swift and GitHub Actions updates targeting main, group routine updates with finite PR limits, preserve exact action pins, and review dependency changes with a read-only workflow. Preserve the existing quality and main-only Sonar checks. Every PR requires `@codex review`, fixes and repeated review until clean, plus required checks; do not auto-merge or bypass protections. Explain actual ecosystem coverage and distinguish configuration badges from security findings.

## Evidence and limits

On 15 October 2026, the dependency graph API lists only `.github/workflows/ci.yml` with checkout and upload-artifact; its SBOM does not include TOMLDecoder. GitHub documents Swift 5/6 version and security-update support, but actual Swift advisory coverage is unverified here. SHA-pinned Actions do not receive Dependabot vulnerability alerts, although version updates can refresh their commits. No dependency versions, gameplay, saves, packaging or Homebrew instructions change in this slice.

Tracked in [Elite PR #17](https://github.com/stephenlclarke/elite/pull/17).
