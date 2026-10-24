# Avoid retaining the previous simulation for audio transitions

## Problem

The main-actor audio presenter retains an entire `Game` between frames. Its comparisons only read docking state, kill count, message text, speech enablement and the speech namespace epoch. Retaining the world also retains its scene, commander, mission and other copy-on-write storage while the actor advances the next frame.

## Acceptance

Keep only those five transition facts in the audio presenter. Preserve launch, docking, explosion, notification, speech cancellation and discharge behavior, including the initial docked/zero-kill/empty-message/muted defaults and the first speech namespace reset. Keep all simulation mutation inside `GameRuntime` and audio on the main actor.

## Validation and limits

Review every former `previous` read against its replacement and run the existing discharge, speech and native frame regressions. Run the required maintained CI gates before release. Removing the retained simulation is a source-level memory improvement; it is not a measured frame-rate or peak-memory claim.

See [the implementation handoff](PR-audio-snapshot-retention.md).
