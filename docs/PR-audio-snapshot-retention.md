# Reduce retained audio transition state

## Change

`AudioPresenter` now remembers docking state, kill count, message text, speech enablement and the speech epoch directly. It no longer constructs and retains a second `Game` for comparisons. The comparisons and update order are preserved, including a namespace cancellation on the first update. Audio remains isolated to the main actor; the simulation actor and its snapshots are unchanged.

## Validation

Independent source review found no actionable behavior change. Formatting and Markdown lint passed. Root149 compiled the change and passed all 52 selected methods at `312b52878ef4a01fbae39a0e6997ca36e30d01aa`, including discharge, speech and actual native frame processing. Source, the human commander save and preferences were unchanged, and all owned validation processes exited. This validates surrounding event behavior and native execution; it does not assert audible playback quality or measured performance.

## Compatibility and risks

There are no save, equipment, controls, sound format or public API changes. There is no frame-rate claim or numerical memory benchmark. Full coverage, sanitizer, leak and release acceptance remain separate gates, the mission-ledger regression now passes in the focused run; full-suite acceptance is still pending.

See [the issue](ISSUE-audio-snapshot-retention.md).
