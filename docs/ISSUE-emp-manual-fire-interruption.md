# Incoming damage incorrectly latches manual EMP firing

Diagnostic 338 at `edf5bc2786721e8f03bf90f0341b57fe7a3e7403` preserves the original native flight controls and 800-frame budget. All three selected cases end in actual stationary-player death at 25.5 or 29.5 seconds, with no docking or thermal failure. All 716 compiled artifacts, 2,087 committed inputs, protected files and original process closure were verified; this is failed diagnostic evidence, not native acceptance.

The production damage handler classifies every selected tool except the combat laser as extraction work. Positive damage, including shield-absorbed damage, latches firing suspension. The common firing boundary then refuses another EMP charge until the held trigger is released without further incoming damage. This conflicts with the existing manual offensive override that already groups EMP with combat lasers. Fitting more shields does not remove this control latch.

Limit damage-only selected-tool interruption to Mining Laser and Salvage Cutter. Preserve interruption of any actual work guidance/braking, actual shield/hull damage, ten-second EMP charging, ECM cancellation, electrical disablement, identity/occlusion/cost checks and atomic publication. Keep both original native fixtures and their useful failure diagnostics unchanged.

[PR handoff](PR-emp-manual-fire-interruption.md).
