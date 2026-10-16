# Canonical courier reach adapter owner review

Source review on16October2026 of Mission Coder commits `819ae2b85073e3e05ee23d37f9a33d9d9dd4e4a8` and `ff5598550e962c62e1666c35c1bbfd4590558fd6`, isolated `feature/mission-canonical-composition` from accepted documentation base `cf30ef550347ed95895e6316b93863bb169372de`. All five production/test/document hashes match immutable Git blobs, and the supplied patch matches SHA-256 `cbeb375e0d28bed5aac37354076ecfafbb5c9c3bbc866f16a452327c7576b6d8`. Handoff: `/tmp/elite-mission-canonical-reach-ff55985-handoff.json`.

## Production source disposition

No production-source blocker found in this bounded adapter. New captures use the agreed `elite-canonical-native-reach-v2`, effective jump cap/fuel multiplier and actual first/full-tank native range. Required optional fields are coherent for v2 and nil for v1. Finite nonnegative multiplier zero follows the actual native capped branch without division. `laterReach` supplies the old formula only for legacy snapshots, and route construction checks `reach.valid` before using it. Current acceptance rechecks the frozen route against actual native first/full-tank reach.

The v1 tier/capacity/fuel mathematics, breadth-first ordering, six xorshift draws, generation revision1, frozen paths/rewards/durations and native container21 remain unchanged. Subsequent refits do not reinterpret a saved snapshot using the current component. Production scope is exactly `ScriptCourierGeneration.swift` and the one later-leg expression in `ScriptCourier.swift`; no save publisher, phase boundary, Lua interface or unrelated mission code changes.

The native zero-cost boundary is now independently source-verified at clean central `c6ea36cacada8ab1fd74ef494821108953b0d85d`: `EffectiveEquipmentValidation.swift` checks positive nonoverflowing capacity, capped actual reach and the applicable native search radius before admitting a Commander. Military zero-cost can remain safe where Basic zero-cost produces an invalid search radius. The submitted positive fixture preserves the actually purchased item's identity/provenance/history and existing receipts, modifies only the admitted grandfathered statistics, and calls native load admission before courier generation. It does not claim a fabricated recovered-upgrade receipt.

## P2: legacy regression needs an independent anchor and accepted job

`ScriptCourierCanonicalReachTests.swift` lines168-206 generate a current v2 board, recursively replace its reach revision and remove the two fields, then compare the resulting board's draws, paths, rewards and durations with that same generated board. This exercises optional-field compatibility, but cannot independently detect a change to historical generation/replay. It also tests no accepted v1 job, protected item, issue/completion proof or absolute deadline.

Route the correction exclusively through Orchestrator to MC1: retain an immutable v1 serialized board and accepted-job fixture from the accepted G02 baseline, or an independently version-pinned v1 golden vector. Reload it under the actual canonical model and after a legitimate refit. Assert the original draws, route, reward, absolute deadline, job/item identity, custody and retained receipts are unchanged, with no reroll or reissuance. Keep the existing new-v2 purchase/recovered/first/later/refit/zero-cost fixtures. Use the central native-invalid Basic zero-cost case during composed validation rather than admitting it through a courier-only predicate.

## Verification limits and next gate

The five methods/seven declared invocations are uncompiled and unexecuted. The isolated Mission base intentionally lacks the canonical Commander/FuelStorage types and shared recovered-equipment test helper needed to compile these fixtures. Source review is not a passing test, an executable acceptance or formal PR approval. Once the pinned fixture correction and canonical composition are ready, run focused compatibility/native tests and full `make ci` under the assigned exclusive slot, preserving accepted stack/transaction fixes and all original G02 evidence. No Researcher runtime edit, build, test, native workload, push or PR was performed.
