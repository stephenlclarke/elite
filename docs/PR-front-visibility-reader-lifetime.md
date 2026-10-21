# fix(targeting): resolve front visibility geometry before drawing

## Motivation and implementation

Front target acquisition currently resolves station authority while Display.draw is active. visibleInFront now resolves front.scriptNPCMesh(body) ?? front.gameplayMesh(for: body) after selecting the front view, then passes the resulting Mesh to the unchanged renderer. The nil-coalescing precedence stays lazy; an empty unauthorized native mesh remains an explicit mesh and cannot fall back to legacy geometry. Frame setup, rasterization flag, projection, clipping and visibility result remain unchanged.

Only TargetingComputer.swift, an appended TargetingTests regression and these paired notes change. No shared reader/storage, renderer implementation, station predicate, actor isolation, stack limit, timeout, concurrency, controller or G12 change is included.

## Validation and compatibility

The new frontVisibilityPreservesGenuineNativeStationGeometryAndRevokedAuthority method has three display-style cases. Each uses the real native-station launch fixture, reframes only the observer to view each admitted station, and requires visibility before and after restoring authority. It refuses a mismatched retained body binding, missing native world and actual ledger tombstone. Reads preserve the world, flight state, selected screen and display style. Existing tests are unchanged.

G1's focused selection is four methods/six cases:

- narrowRefinementRefusesOversizeOrientationWallContactAndStaleAttainedMotion: unchanged actual fault producer, one case.
- attainedNarrowSH171StepRefinesTheUnchangedApertureAndWholeHullProof: unchanged positive whole-hull/aperture authority, one case.
- frontVisibilityUsesRenderedEdgesAndChangingMembershipNeverRepeatsVisitedShips: unchanged rendered-edge clipping and target membership, one case.
- frontVisibilityPreservesGenuineNativeStationGeometryAndRevokedAuthority: new genuine station boundary, three cases.

Author validation is source-only formatting, strict lint, paired Markdown and diff/preservation checks. Matching native compilation and six cases remain pending with G1; independent review and required hosted CI remain pending. No author native build, test, probe, debugger or duplicate symbolication occurs. This is a bounded call-lifetime correction, with no measured frame-size or complete crash-repair claim. See [the retained fault and uncertainty](ISSUE-front-visibility-reader-lifetime.md).
