# Original ship designs in the README tape

The maintained `make readme-media` export currently rotates SH123 Larvaal Sovereign in the opening and title scenes, then shows commander status and legacy flight geometry. A status label naming SH025 does not demonstrate that ship's original model. The README tape needs visible, identifiable original designs in the plural.

Append deterministic design presentations for SH002 Gyrfalcon Assault and SH035 Stag Liner using the authenticated original fleet assets and the maintained game renderer. Identify them with canonical original definitions. Present them explicitly as designs; do not manufacture ownership, discovery, encounters, catalogue activation or flight records.

This source batch is restricted to `StartupDisplay.swift`, `NativeGraphics.swift` and the media exporter in `L337App.swift`, plus the paired notes and the reserved `Tests/L337CoreTests/ReadmeOriginalDesignPresentationTests.swift` test file. README prose belongs to G3. Existing media and the live integration checkout belong to G1.

No compiler, tests, native app, GPU, game renderer or media generation may run in this source-only batch. G1 must execute the new tests and generate the tape with `make readme-media` after the source is frozen. Because `NativeGraphics.swift` participates in the gallery renderer fingerprint, any affected gallery generation must use the same final source composition; changing a stored fingerprint without generating its media is insufficient. Visually inspect the resulting full-resolution scenes before claiming the tape demonstrates both original designs.

See [implementation and pending validation](PR-m03-original-design-tape.md).

## Actual focused and media qualification — 30 October 2026

Frozen a4250b1e passed all23 affected methods in11 suites, including all20 previously failed methods, the three new presentation methods/five cases and genuine HQ destruction/tombstone/cold load. The test phase completed in111.203 seconds, build129.01 seconds; no full CI/leak/Sonar/release result is inferred. Independent source and actual-result reviews are clear.

The maintained `make readme-media` and guarded `make ships` both passed on that source. The tape decodes80frames at1024x768/160ms with infinite looping. Frames48–63 present authenticated SH002 Gyrfalcon Assault;64–79 present SH035 Stag Liner. Representative start/end rotations show their real geometry, textured materials and canonical captions; all32 new frames have identical opaque header/footer crops. All171 gallery GIFs were actually rendered, zero reused; their24-frame/256-square/100ms structure, overview2560x4608 and `make ships-check` pass. Of181 inventoried outputs,179 remain byte-identical to the source parent. Only the tape and gallery input-fingerprint manifest change.

The old48 scene-generation path is preserved. Decoded old/new prefix RGBA is not identical: measured colour differences and representative content comparisons are retained without an inferred encoding cause or pixel-identity claim. No manual image assembly, raw ship/texture modification or extra profiling occurred. Complete source/input/output/frame evidence is in `docs/evidence/M03-a425-final-media.json`. Independent final media review and fresh final-head CI remain pending.
