# fix(ui): keep cockpit weapon text at the shared logical size

Cockpit text columns now use the fixed `font` value. The weapon-status row uses `layout.font` for both centering and label scale. These three substitutions restore the existing1.25 logical bitmap scale across window sizes and keep wrapping and positioning consistent with the rendered glyphs.

Instrument scaling, row spacing, scanner geometry, weapon authority/snapshots, control behavior and Game state remain unchanged. `GameTypography.scale` itself remains1.25. README already documents exactly this fixed-size behavior, so it needs no new product claim. No help binding or page content changes.

## Evidence and validation

The actual CI log at `/tmp/elite-full-review-ci-560/ci-560.log` reports45 line18 failures, all the weapon-status text at scale1.5 or2. There are15 affected screens and three larger widths each;512-wide text already meets the contract. This is a source repair for that specific failure, with no assertion, expectation, tolerance or test-fixture changes.

Reversing the three substitutions restores the entire parent `CockpitDisplay.swift` byte for byte. All test files remain untouched. Author checks are strict Swift formatting, paired-note Markdown lint, whitespace checks and source correspondence. No author compiler, native, GUI, runtime, test or profiling jobs were run.

G1 owns one independent review and batched build. Existing direct regressions are `nativeTextUsesOneFixedLogicalSizeAcrossEveryScreenAndWindowSize`, `FlightControlInputTests.weaponRowIsReservedAboveScannerAcrossViewsStylesAndSizes` and `FlightWeaponSnapshotTests` (weapon display wrapping and immutable snapshot rendering). The existing typography test checks exact scale and viewport bounds on every screen at512,768,1512 and2560 widths, including the concrete unavailable-snapshot case. The weapon-row test covers real prepared weapon text, all four views and display styles at320 through2560 widths, and scanner separation. The other two `TypographyTests.swift` tests retain equipment click/reflow and compact page coverage.

This leaf does not claim to fix the separately reported helper SIGBUS, complete full CI or change the retained fresh salvage acceptance. Root/G1 own subsequent official gate allocation.
