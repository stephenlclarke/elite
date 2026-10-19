# feat(freight): add exact untimed bonded machinery profile

## Problem and resulting behavior

The new l337.contract/bonded-freight exact profile uses three issuer-owned machinery tonnes and a separate 750 native-unit deposit. Its frozen quote is 4800 + 950*L + 800*H, where L is the full selected native route leg count and H is explicitly declared in content. Default duration is zero and deadline is nil. Physical loss/escape and issuer abandonment still use existing freight terminal settlement; this exact untimed profile cannot expire.

## Implementation

ScriptFreightGeneration.swift adds a bounded quote value, explicit declared row hazards and selected immutable quote values, exact profile/state matching, machinery/quantity/deposit terms, and profile-dependent deadline/payment validation. Existing three-row/six-draw structure is retained. The untimed profile uses the existing native reachable route pool without applying the legacy deadline feasibility filter. Legacy route selection, rewards, quantities, durations, declaration constraints and exported generator shape are preserved. Only bonded generator values add deposit, route_legs and hazard_tier.

ScriptFreight.swift and ScriptFreightCollections.swift admit nil deadlines only for the exact bonded profile. Native issue/contact/current dock, owner, epoch, choice, held-unit and durable candidate checks remain. The resolver still processes actual physical loss/escape with nil deadline. ScriptOwnedCargoState.swift validates reward-plus-deposit terminal money and rejects expired untimed terminals. Completion receipt settlement matches the actual existing settleContract amount. ScriptContractCore.swift and its debit/refund/duplicate/overflow authority are untouched.

## Validation

Eight focused Swift tests are AUTHORED UNRUN: full route/hazard quote arithmetic and overflow, actual generated profile/goods/deposit/nil-deadline terms, forged quote and legacy isolation, existing settleContract success-plus-deposit/duplicate refusal, failure/abandon no refund, and reload/hidden-deadline refusal. Tests use a temporary copied legacy pack with explicit fixture hazard tiers [0,1,2]; no production tiers are invented. The source-only lane does not execute Game, Swift compilation, make ci, coverage, sanitizers or leak gates. Portable source and patch checks are recorded in handoff.json; Python arithmetic evidence is an independent content oracle, not Swift execution. Markdownlint and Swift formatting are UNRUN in this lane.

G1 must compile/run the new focused tests and existing freight generation/acceptance/custody/persistence/native writer-failure tests on the final integrated head, then project gates. New-profile native confirmation debit-once, real partial/final delivery, reload and writer-failure routes remain required native integration evidence.

## Compatibility and risks

Base ba47c87435df08fd29f3ee980af66b106f293a5d. No canonical edits, push, merge, old-save migration, new ledger or new scheduler. New optional saved fields remain nil for legacy plans. New-profile declarations require explicit bounded hazard tiers for all three rows; profiles and state IDs must match exactly. Saved descriptive inputs do not themselves prove runtime admission: pack matching, current native owner/custody/dock and existing writer authority must continue to validate provenance. A content pack is still required before playable completion, including honest quotation of full route legs, hazard and separate deposit. Optional timed variants remain disabled.

## Links

ISSUE-g03-bonded-freight-profile.md; UX ledger MBA-01; M05/G03. Content authority original-missions/original-families.md:71 and original-families.json l337.contract/bonded-freight row. No GitHub PR has been created.


## Revision 2 independent review fixes

G2 found that the original packet could not load its actual TOML declaration and could not pass the actual versioned save preflight. Root reserved ScriptPack.swift and ScriptFreightVersionedSave.swift in addition to the original four production paths. The loader now admits the declaration field and existing closed-profile validation still rejects it on the legacy profile. Versioned preflight permits exactly the bonded 23-key plan shape only for the exact profile, requires a three-element hazard array and exact two-field non-null quote, and preserves the legacy 21-key shape. Existing typed decode and cold/native validation remain mandatory.

Two additional test functions exercise six actual pack-loader refusals and a real native board/issued-job ScriptSaveStore roundtrip with deposit debit-once and 18 rehashed chunk corruptions across contracts and missions. These supplement the original six methods. Revision 2 is REVIEW PENDING and EXECUTION PENDING, not ready for integration. MBA test execution was attempted once and stopped before compilation with Xcode license exit 69, zero executed tests, 0.40 seconds. Root/G1 reserved a local isolated focused executor after the M01 lease closes; the author retains test and fix ownership. No license acceptance or unchanged retry occurred. The original packet and hashes remain unchanged.
