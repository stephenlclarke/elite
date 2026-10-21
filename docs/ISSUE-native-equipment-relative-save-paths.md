# Use one contained relative path convention for native equipment saves

## Recorded failure

Validation 343 completed 21 methods/24 selected cases at `34691a216cc09d23d921535b0b6707f01da1ff98`. The three native equipment publication methods each failed at the new helper's line 1006: `files[pointerPath] == bytes` was false, and `bytes != fixture.originalSave` was not evaluated. Earlier throwing independent live/view/stored Commander, world, schema, codec and new-generation checks completed. Old-generation conservation, exact added files/chunk hashes and post-commit replay were not reached; these methods did not pass. The separate EMP failures belong to G1. Raw log: `/tmp/elite-emp-save-geometry-fast-focused-343/candidate-343-attempt-01.log`, SHA256 `ad9917b958944ab9343f2fcf9dab129938379a0da4c062296ba3b5faaadf2f7d`.

## Source-backed cause and correction

The collector sliced each enumerated absolute path by the supplied directory string length without proving a shared normalized prefix. The new pointer lookup independently assumed a leading slash. Expected generation paths and replay pointer lookup also used separate conventions. Existing original-file comparisons treated the collected keys as opaque, so their prior passes did not establish a leading-slash contract. Host aliases and directory separator spelling make blind string offsets unsafe. No actual key/URL operands were dumped; a particular host offset remains an inference.

Use one private helper, patterned on the unchanged `NativeWorkGuidanceTests.nativeWorkRelativePath`, for every collected or expected key. Resolve symlinks and standardize both root and candidate URLs, compare path components with a strict descendant-prefix requirement, and join only the remaining components with `/`, without a leading slash. Refuse duplicate canonical keys explicitly. Keep every collected file byte; no observed-key copying, lookup fallback or new state oracle is allowed.

The shared collector, positive pointer lookup, exact four added generation paths, individual chunk hash lookups and refused-replay pointer lookup must use that same helper. Keep original pointer/tree immutable and require the complete independently expected Commander/world, exact schema/codec/new generation, old bytes, exact four added paths and actual chunk hashes before returning any post-commit checkpoint. Preserve whole checkpoint equality after explicit stale refusal.

## Scope and validation

The parent is preserved `e1f952b1ebdbf7373ffeade0c2a7ecf84c9ca0a3`. Only `NativeEquipmentViewTests.swift` and this new issue/PR pair change. Three existing helper bodies and one new private relative-path helper form the source scope. The collector's eight static calls affect all eight native equipment fixture methods/eight cases: three failing methods and five formerly passing callers. All eight method bodies, shared bootstrap construction, `verifyUnchanged`, existing domain expectations and all unassigned source bytes remain unchanged. NativeWork, production, legacy station follow-up and G1 work are excluded.

Formatting/parsing, strict lint, Markdownlint, static assertion-effect/scope/caller/selection/hash checks are the only local validation. No compiler, discovery, tests, build, native/UI/media or GitHub jobs run. Root reviews the frozen child before G1 schedules execution. Existing 343 evidence and original 344 qualification remain preserved; no runtime pass is claimed. See the [PR handoff](PR-native-equipment-relative-save-paths.md).
