# Reduce retained audio transition state

## Change

`AudioPresenter` now remembers docking state, kill count, message text, speech enablement and the speech epoch directly. It no longer constructs and retains a second `Game` for comparisons. The comparisons and update order are preserved, including a namespace cancellation on the first update. Audio remains isolated to the main actor; the simulation actor and its snapshots are unchanged.

## Validation

Source review confirms all five previous-state dependencies have matching replacements. Formatting, compilation and runtime checks will be recorded after execution. Existing discharge-event and speech-feed regressions, together with native frame processing, cover the surrounding behavior; no playback or performance result is claimed before validation.

## Compatibility and risks

There are no save, equipment, controls, sound format or public API changes. There is no frame-rate claim or numerical memory benchmark. Full coverage, sanitizer, leak and release acceptance remain separate gates, including the already known mission-ledger test setup crash.

See [the issue](ISSUE-audio-snapshot-retention.md).
