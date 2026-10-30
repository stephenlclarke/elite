# Original ship designs in the README tape

The maintained `make readme-media` export currently rotates SH123 Larvaal Sovereign in the opening and title scenes, then shows commander status and legacy flight geometry. A status label naming SH025 does not demonstrate that ship's original model. The README tape needs visible, identifiable original designs in the plural.

Append deterministic design presentations for SH002 Gyrfalcon Assault and SH035 Stag Liner using the authenticated original fleet assets and the maintained game renderer. Identify them with canonical original definitions. Present them explicitly as designs; do not manufacture ownership, discovery, encounters, catalogue activation or flight records.

This source batch is restricted to `StartupDisplay.swift`, `NativeGraphics.swift` and the media exporter in `L337App.swift`, plus the paired notes and the reserved `Tests/L337CoreTests/ReadmeOriginalDesignPresentationTests.swift` test file. README prose belongs to G3. Existing media and the live integration checkout belong to G1.

No compiler, tests, native app, GPU, game renderer or media generation may run in this source-only batch. G1 must execute the new tests and generate the tape with `make readme-media` after the source is frozen. Because `NativeGraphics.swift` participates in the gallery renderer fingerprint, any affected gallery generation must use the same final source composition; changing a stored fingerprint without generating its media is insufficient. Visually inspect the resulting full-resolution scenes before claiming the tape demonstrates both original designs.

See [implementation and pending validation](PR-m03-original-design-tape.md).
