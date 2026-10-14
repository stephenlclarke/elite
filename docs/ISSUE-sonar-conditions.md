# Readable chart and celestial bearing conditions

## Motivation

The authoritative main analysis of `34790e313c0d6cf8be84fe74aaf8f2f228cd3b3f` passed its quality gate but reported three `swift:S3358` findings: two nested bearing expressions in `CelestialFlight.swift` and one nested docked chart footer expression in `ChartDisplay.swift`.

## Acceptance

Make the conditional choices explicit while preserving the original directional thresholds, strings and chart dimensions. Existing four-view bearing and compact-chart regressions must pass, followed by complete coverage, sanitizers and leak checks. Rebuild and notarize version 1.3.1 from a clean checkpoint and verify the final protected main scan has no open findings. Keep all ship data and existing commander saves unchanged.
