# Gallery input and native save preparation retain later-phase storage

The original failed Gallery retry still failed with signal 10 after the known-world persistence phase compiled at checkpoint 186. The next exact-binary debugger reproduction at 187 passed the nil-world station path and stopped in `registerDestroyedCargo`, called from destruction resolution inside `prepareNativeSaveState`. No matching original 186 OS report establishes equivalence.

## Actual audit and required repair

The unchanged save-preparation object retains two Game and two Commander slots before the deep destruction call. One Game is the required atomic candidate; it must remain. The other storage serves both early docking-evidence guards and later validation/publication work, so extracting only one side does not retire both lifetimes.

Keep `var candidate = value` and the exact station persistence → equipment preparation → equipment mirror → destruction resolution order. Move the complete original docking-evidence guard into a private synchronous `inout` helper returning before persistence. Move the complete original post-resolution tail into a second private `inout` helper returning the unchanged Game/Commander tuple. Preserve every pose, salvage, NPC, unsettled-death, validity, disk-binding and publication rule.

## Acceptance

Inlining both helpers must reconstruct the complete old file exactly. No required atomic copy, native authority guard, writer behavior, test, stack setting or boxed Game state may change. Strict source lint and whitespace checks precede actual compiled shape, the original failed method, related save/station cases and final maintained gates. See [the implementation handoff](PR-native-save-frame-phases.md).

## Same observed spine: actor key fallback

The exact 186 runtime-key object reserves two whole-Game value-witness-sized stack buffers before `galleryAction`. Both belong solely to its later fallback: the actor Game read and catch rollback. The actor's stored heap Game is not counted. Preserve the public early Gallery dispatch, then move the entire old remaining body into a private synchronous actor-isolated fallback. Keep the required `before`/`held` copies, commands, durability handling and catch rollback there. The all-three inverse-inlining check must reconstruct the complete original file.
