# feat(missions): add native verified hostile warrant

## Result

The default Avenor board offers an untimed L2/H0 warrant on one uniquely identified armed aggressor at Renas. The player must destroy that actual actor, return to Avenor and confirm Voss's report before receiving 1120 CR and the first verified-warrant family clue. Failure and withdrawal pay zero.

## Implementation

The production pack uses an existing profiled NPC with catalogue geometry, a working native laser and attack-player intent. The exact G06 guards recheck the actual issuing dock, front weapon and route at acceptance, then consume native player attribution and a current Voss station choice before existing settlement. Retained completion validation checks the same historical proof after later travel and reload. Standard discovery, digest dedup and clue pin are appended without changing other providers.

## Validation

The matching cached MBA build and native pack CLI passed on `709c91cea7b923fa30ce896c641f620d28f27eac`, with production digest `f125be8200d0dd3ae834f2dc4cd52da46f7c571de7e67cbec61f76c7beab9911`. Focused owner qualification is an explicit **16-method / 22-case aggregate**, not one full run: the final 15 affected methods / 19 cases passed, with the unchanged G01 native method / 3 cases retained from its explicit PASS on `ac9e6fac252df815d3df8ee2d1e9fd20c8992b3b` by byte and exact-G06 branch dependency proof.

The passing cases exercise actual native issue, Avenor-Renas-Avenor travel, player laser damage and target attribution, Voss report and exact settlement; Back and stale changed-fitting refusal; unrelated, clean, non-player and actual removal refusal; zero-payment failure/withdrawal; current Normal/Alien envelope joins and rehashed attribution/report stripping; successful completion followed by real later travel/reload; unique repeat actors with one retained clue; acceptance/report writer rollback and retry; and default ordering/dedup. The non-player case uses a real current native station emitter and measured target ray through the existing mission-NPC impact/projection adapter. Empty Alien storage verifies the current envelope, without claiming Alien acquisition.

Both test compilation failures and both failed owner runs are retained. Causal fixes separated test macro operands and stale-token accesses, corrected the Lua command to native `actor.intent` with normalized speed 1, prevented re-admission of a completed cohort, and selected the proper native NPC impact adapter in the non-player fixture. Native bindings, reward, successful proof predicates and producer code were not weakened. No crash, timeout, stack/concurrency override or cache purge occurred. The final matching build, CLI and owner run closed cleanly with source, binary and preferences unchanged. Postprocessing the existing matching SwiftPM coverage profile reports 94.53% line coverage for `OriginalVerifiedWarrant.swift` (121/128 lines), with all 12 functions exercised. The exact profile and report are retained; this is not an overall project coverage claim. Independent full-boundary review is pending.

## Compatibility and limits

Existing state, actor, choice and completion representations remain authoritative. There is no new timer, cargo, ledger, Game/Director/save schema or producer change. This work does not resolve pre-existing MAIN/release failures or establish app/release readiness. Related issue: [ISSUE-original-verified-warrant.md](ISSUE-original-verified-warrant.md).
