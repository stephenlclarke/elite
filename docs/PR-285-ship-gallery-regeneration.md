# fix: regenerate L337 ship gallery fingerprints and links

The existing guarded `make ships` completed successfully on75e7453c and reports171 rendered, zero reused. All171 GIF files were actually written. `make ships-check` then passed all171 specifications, animations and reference sections.

The175-output inventory covers171 GIFs, overview, manifest, catalogue and provenance. All171 GIFs retain24frames at256x256,100ms and infinite looping; overview remains2560x4608. Exactly173 output files are byte-identical to the parent, including every GIF, overview and provenance. The only generated changes are171 new manifest input fingerprints with unchanged output digests, and172 exact catalogue link replacements from the old module path to L337Core. Runtime, renderer, raw TOML and texture sources remain unchanged.

`docs/evidence/M03-ship-gallery-regeneration.json` binds every actual output, the source trace, successful command/check and earlier native failure. Existing resource admission/RSS/lease safeguards remain intact; no additional diagnostic profiling occurred. Retain earlier40-method Swift and eight-method planning PASS; no unchanged local Swift run is repeated. Independent changed-output/evidence review and fresh final-head CI/source-execution policy remain required. Full normal, leaks, main Sonar and release are still pending.

The ledger separately credits existing F27 source and records the precise source-authoring dependencies for later C10/C38 stages. These documentation updates do not implement or qualify new gameplay.

Related issue: [285](https://github.com/stephenlclarke/l337/issues/285). Parent PR: [283](https://github.com/stephenlclarke/l337/pull/283).
