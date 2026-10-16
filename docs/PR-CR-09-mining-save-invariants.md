# CR-09: Validate bounded mining persistence

MiningLedger now incrementally decodes its existing non-string-key dictionary representation with explicit bounds and duplicate-key rejection. Its validity check covers system/rock ranges, terminal masks, finite positive partial energy, deterministic source-seed ore amounts and identities, finite motion, unique live cargo actors, offers and their references, visits and allocator high-water values. Normal admission rejects impossible acknowledgements and avoids sequence wrap. The encoded schema remains unchanged; a missing optional commander mining field remains supported.

The Commander.valid hookup is isolated in a separate shared Game.swift integration commit. New tests cover valid empty/partial/extracted and bound-motion roundtrips, malformed energy/identities/counts/canonical quantities/bindings and absent legacy optional state. One old receipt fixture now assigns a distinct actor to each admitted pod, retaining its original retry/cull assertions.

Validation is pending the numbered validation lease. Source formatting and whitespace checks pass; no executed build, test, sanitizer or native result is claimed. Motivation: [issue](ISSUE-CR-09-mining-save-invariants.md).
