# Weapon status grows with window width

Official CI560 on e26595397db8d297978f0b89cd146b782416d49e reported45 failures in `nativeTextUsesOneFixedLogicalSizeAcrossEveryScreenAndWindowSize` at TypographyTests.swift:18. Every failure named `WEAPON: UNAVAILABLE / SNAPSHOT REQUIRED`, across15 cockpit-bearing screens at the three larger tested sizes. The label scale was1.5 or2 instead of the shared1.25. The512-wide case already used1.25.

`CockpitLayout.font` is fixed to `GameTypography.scale`, while `instrumentScale` intentionally grows with available width. The added weapon row accidentally used instrument scale for its label and centering. The shared cockpit text wrapping width also used instrument scale, limiting lines according to a different glyph size from the other fixed-size HUD labels.

Restore the existing user requirement and README contract: every screen uses the same small logical font, including full screen and Retina windows. Text wrapping, positioning and rendering must measure that same font. Instrument geometry and its row reservations can keep their current responsive proportions. Preserve all existing fixed-font, layout and weapon snapshot assertions.
