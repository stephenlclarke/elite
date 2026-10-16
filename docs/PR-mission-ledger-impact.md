# feat(combat): consume sealed mission impacts in scoped ledgers

## Result

Add internal `CrimeLedger.recordMissionReentryImpact(_:eventID:outcome:context:)` and `MiningLedger.hit(rock:proof:eventID:context:)`. Both require an actual sealed impact proof, the allocated native physical event ID, and the same validated pre-damage context. G1 applies the returned changes atomically with the physical outcome.

## Implementation

Crime checks current system, visit, revision, projectile and target facts, and refuses a stale known source before consuming the event. A fresh proof with an unknown source remains valid for physical effects. Only frozen launch attribution for the same intended durable victim maps historical source, victim and aggressor to verified current addresses. Unknown destruction records only an irreversible victim tombstone. Frozen legal effects preserve launch law and apply once per attack window; reports use the actual contact transformed through the current camera. Ordinary current-visit admission is unchanged. The shared death arithmetic does not clear unrelated ordinary missile threats for scoped plasma.

Mining validates the actual physical rock contact and uses only damage from the sealed plasma proof. The existing public API and scoped API share one private physical-hit implementation, including event monotonicity, partial and pending capacity, tombstones and payload custody. Plasma produces no mining ore.

## Validation and limitations

`MissionLedgerImpactTests` constructs actual retained profiled packs, native source and projectile identities, frozen native judgement and geometric impact proofs. It covers revisit law and unchanged ordinary visit refusal, duplicate events, fresh unknown/incidental impacts, unknown-death replay, stale source/role/target/scene, ordinary crime and mining parity, partial capacity, terminal plasma damage and pending ore custody. Ordinary ledger calls seed the retained-capacity fixture; they do not construct a sealed capability.

`MissionLedgerImpactTests` has 10 authored test methods and 13 parameterized cases, all UNEXECUTED. The temporal regression uses an actual produced proof at physical time two, refuses an earlier restored clock before consuming the event or death, then verifies exact-now and older-launch positives.

Swift formatting and diff checks pass. Compilation and all tests remain unexecuted pending the assigned lease. The base is `dd780a0c1e1f00abbe2de82bd984e400c5cfdf8f`; the minimal API pin is `ac37c594c3cd4ea7b65266fb177beebabe8b83db`. The source chain is `ac37c594c3cd4ea7b65266fb177beebabe8b83db` (minimal APIs), `535f29fc323417ea81bd9856f198ecf0497cbccb` (stale-source refusal and producer-based tests), and `0e91cb05c9df6aededcb2924e2db9f84411a6e8c` (future-launch refusal). Root has independently source-reviewed the temporal correction; G2 independent review and composed compiler/runtime validation remain pending. Owned ledger source is stable pending that feedback. No PR has been published by this slice.
