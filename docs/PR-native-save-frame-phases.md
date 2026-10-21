# refactor(runtime): separate Gallery input and native save phases

Native save preparation retains its required atomic `var candidate = value`. A private `inout` helper evaluates the exact original docking-evidence guard before native persistence. The original persistence, equipment preparation, mirror and destruction calls stay in order. A second private `inout` helper then executes the entire old remaining tail and returns the same Game/Commander tuple. See [the issue and exact scope](ISSUE-native-save-frame-phases.md).

## Preservation and validation

Inlining all three helpers reconstructs the entire previous `Game.swift` exactly. Cargo/ore/salvage poses, salvage refusal, Blackjack state, NPC persistence, unsettled/dead-body/Commander guards, the disk Commander copy and positive-count binding reset retain their complete original contents and order. No new value argument, save candidate, writer path, authority, test change, input normalization, stack flag or boxed state is introduced.

The prior known-world phase compiled at 186 on `6e41f78d4bcce4e85492a35b61efcc33a3135e3f`, but the same original method still failed with signal 10; raw log SHA256 `d34f318b857eff0429522bd94183b4b7a55c33037ab50a4a1df4cfc9d84e9322`. Debugger 187 advanced past nil-world persistence and stopped in cargo destruction registration. The actual unchanged save-preparation object has two Game and two Commander slots before resolution. These are old-object facts, not a measured new-frame reduction or runtime pass. No matching original OS report establishes 186 equivalence.

Whole-file inlining, strict Swift source lint, Markdown lint and whitespace checks pass. This new source is uncompiled and unexecuted. Actual new-object inspection, the original failed Gallery method, related station/save regressions, renderer fingerprint regeneration and final composed `make ci` remain required. External review, final-head checks and protected merge remain separate release gates.

## Actor key fallback on the same fault spine

The public actor `key` retains its exact early `if galleryAction(key) { return }`, then calls private synchronous `keyAfterGallery`. That helper contains the complete old fallback: courier resolution, `before`/`held`, key application, subsequent resolution/durability, game-over pack restoration, commit and catch rollback with controls and message. No actor hop, asynchronous yield, input ordering or public API changes. The required fallback rollback copies remain.

The exact old runtime-key audit on source `6e41f78d4bcce4e85492a35b61efcc33a3135e3f` and binary `925b160cafd064870612df3941855122ac6e86334e29242351ffbc848a5b9181` identifies two whole-Game stack buffers before Gallery dispatch, both used only after Gallery returns false. This excludes the actor's stored heap Game. Audit SHA256 `b0d3b411ed5acabc7517537df5a21aa301a706e7aa39862e77e6deacc2da19be`. New compiled reduction and runtime sufficiency remain unestablished; all-three exact-file inlining, strict source lint and whitespace checks pass.
