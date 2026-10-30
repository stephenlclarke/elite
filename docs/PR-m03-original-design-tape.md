# README original design presentation

The README GIF retains the original 48-frame startup, title, status and flight sequence, then appends 16 frames of SH002 Gyrfalcon Assault and 16 frames of SH035 Stag Liner. All 80 frames retain the 0.16-second delay, giving a 12.8-second loop. Each appended scene rotates its model using a deterministic local time and labels its canonical ID and original name beneath `ORIGINAL SHIP DESIGN`, with a `DESIGN PRESENTATION` footer.

`Display.originalDesignPresentation` reads the actual bundled `OriginalFleetShowroomModels` asset and the original catalogue definition. Missing definitions or authenticated assets throw; there is no legacy mesh fallback. The existing showroom normalization changes display framing only and preserves faces, winding, materials, details and texture mappings. The existing `Display.draw` path supplies the shaded geometry, without modifying commander, discovery, ownership or simulation state. Normal startup behavior is unchanged.

`imageForGame` delegates to the extracted `imageForFrame` helper. For valid image dimensions, the CGContext creation, black background, translation, scaling and shared `drawFrame` calls retain their prior values and order. The presentation function supplies the new design frames directly to that same helper. Existing `drawGame` callers remain unchanged.

## Validation pending

`ReadmeOriginalDesignPresentationTests.swift` adds three methods expanding to five cases, all unrun. The two SH002/SH035 cases require canonical original names, rendered textured surface commands and graphics matching the authenticated original mesh, reject a legacy-hull counterexample and require visible rotation changes in drawing commands. Two missing-ID cases require refusal instead of fallback. The final case requires deterministic identical frames and unchanged complete commander (including discovery), bodies, screen, time and normal showroom presentation. These are non-AppKit source tests; no CI inventory change is included.

Independent source review identified that both original designs use textured faces, which the renderer emits as `.textured` commands instead of plain `.panel` commands. The narrow review correction requires actual `.textured` commands for these all-textured assets, preserving authenticated graphics equality, legacy-hull counterexamples, rotation and full state assertions. Production source, models, materials and palettes remain byte-identical to the prior freeze. This correction has not been executed.

This is source preparation only. No Swift compilation, typecheck, tests, app launch, CPU or GPU rendering, media generation or CI execution has occurred. Scoped formatting, whitespace and static source checks are recorded in the frozen handoff. New source and any authored tests remain unexecuted and require independent review and G1 validation before integration acceptance.

G1 must freeze the final integrated source first, execute the focused test coverage, then coherently regenerate the README images and GIF through `make readme-media` and the invalidated gallery assets. `Tools/showroom/ship-reference.py` includes `NativeGraphics.swift` in `RENDER_FILES`, so its source change invalidates gallery fingerprints even though the valid-dimension pixel path is preserved by inspection. Do not bless stale gallery fingerprints. Inspect SH002 and SH035 full-resolution frames for identifiable shaded geometry, canonical labels, useful scale, rotation and clipping. Confirm the first 48 scenes remain intact and the GIF has 80 frames at 0.16 seconds each. Actual renderer output, not source or asset counts, establishes visible completion.

See [motivation and ownership boundaries](ISSUE-m03-original-design-tape.md).

## Actual focused and media qualification — 30 October 2026

Frozen a4250b1e passed all23 affected methods in11 suites, including all20 previously failed methods, the three new presentation methods/five cases and genuine HQ destruction/tombstone/cold load. The test phase completed in111.203 seconds, build129.01 seconds; no full CI/leak/Sonar/release result is inferred. Independent source and actual-result reviews are clear.

The maintained `make readme-media` and guarded `make ships` both passed on that source. The tape decodes80frames at1024x768/160ms with infinite looping. Frames48–63 present authenticated SH002 Gyrfalcon Assault;64–79 present SH035 Stag Liner. Representative start/end rotations show their real geometry, textured materials and canonical captions; all32 new frames have identical opaque header/footer crops. All171 gallery GIFs were actually rendered, zero reused; their24-frame/256-square/100ms structure, overview2560x4608 and `make ships-check` pass. Of181 inventoried outputs,179 remain byte-identical to the source parent. Only the tape and gallery input-fingerprint manifest change.

The old48 scene-generation path is preserved. Decoded old/new prefix RGBA is not identical: measured colour differences and representative content comparisons are retained without an inferred encoding cause or pixel-identity claim. No manual image assembly, raw ship/texture modification or extra profiling occurred. Complete source/input/output/frame evidence is in `docs/evidence/M03-a425-final-media.json`. Independent final media review and fresh final-head CI remain pending.
