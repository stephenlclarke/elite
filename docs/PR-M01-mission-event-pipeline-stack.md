# fix: keep mission publication and validation within the default worker stack

## Problem and result

Native mission acceptance, launch and wormhole publication retained large value temporaries across deeper validation and JSON encoding, exhausting the default worker stack. The change separates preparation, validation and publication lifetimes while preserving the existing guards, event order, error handling and atomic rollback. The real crossing regression now passes without changing worker stack, concurrency or fixtures.

## Implementation

- Keep GameRuntime simulation ownership and current Commander/Game copy semantics. Borrow existing state for admission, snapshots, indexed lookups and validation; enter heavy work only in its original phase.
- Split native save preparation, publication and refusal diagnostics into noninline phases. Keep the encoder, payloads, two 33,554,432-byte semantic limits, file publication and rollback behaviour unchanged.
- Store ScriptInstance values in a private one-element copy-on-write array with checked Sendable/Equatable semantics. Preserve public construction, immutable identity, field visibility, defaults and direct unwrapped Codable. The composed value also retains the already-shipped cold-chain and repair-loop fields and engine checks.
- Preserve native opening/departure/arrival receipt checks and their phase order, salvage/work state, original ship catalogue membership and all qualified current feature hooks.
- Correct independently specified saved-Commander expectations for existing NPC and wanted-career binding normalization, retaining full Commander equality and typed persistent facts.

## Validation

Owner qualification is an explicit aggregate of 31 methods/45 cases, including the real crossing, writer rollback, admission/history, native motion, storage/Codable, malformed equipment and drive-policy cases. It is not one 45-case run. Root verified the source and retained proof joins; the single independent review of all 36 owner paths is CLEAN.

The canonical hunk composition passed its single six-method/six-case qualification, including all current custody keys and mixed Normal/Alien profiles. Root independently reviewed the combined composition seams as CLEAN; all six methods passed with zero issues. Existing qualified W01/W02/W03/G13/T04 content, loader, save dispatch and native hooks must remain intact. Original detailed owner notes are preserved in the composition evidence rather than presented as current behaviour.

## Limits

This is a focused source repair, not full M01 or app/release completion. Final make ci, coverage, sanitizers/leaks, final-head GitHub checks, completed PR review and committed-main SonarQube publication remain required. No stack or assertion waiver, new save schema/codec, cache or actor ownership change is introduced.
