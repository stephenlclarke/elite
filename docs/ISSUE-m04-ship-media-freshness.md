# PR298: refresh ship media after Redtail and Besra activation

## Problem

PR298 adds the reviewed Redtail Mk III and Besra adapters. Its first native attempt stopped at `make ships-check` before game tests, coverage or leak checks. The checker reported all 171 ship GIFs stale because the maintained shared renderer fingerprint includes the changed `ShipPerformance.swift` file. Every GIF was present, matched its recorded output hash and retained the qualified parent's bytes. The missing-files wording did not establish missing images.

## Required result

Use the existing `make ships` renderer path to regenerate all affected outputs. Preserve the guards, original failed attempt and consumed registration. Do not replace freshness validation with a manifest-only update. Keep the README fleet tape, release artifacts, game source and the later controls/EMP queue outside this fix.

The app's `--ship-media` handler writes both the individual animations and `docs/ships/overview.png`. The initial output scope omitted the overview; the actual output check caught this before commit. The original proposal and failure evidence remain preserved, with an append-only correction from 174 to 175 potential output paths. Per-ship GIF transparency is part of the existing format; the separate README tape's opacity requirement does not apply to these GIFs.

## Acceptance

The maintained generation and freshness check must pass. All 171 input/output hashes and GIF container facts must reconcile with actual rendered files. Changes outside the corrected output scope must remain absent. New game tests, isolated selection, coverage and leak qualification still require a fresh final-head CI attempt.

See [implementation and validation](PR-m04-ship-media-freshness.md).
