# MBA-01: implement the approved bonded freight terms using native custody

## Motivation and content authority

The existing PROJECT-SPACE-G03-1 supplied-freight profile intentionally has zero deposit, tier quantities and timed rewards. The approved distinct l337.contract/bonded-freight row instead requires three machinery tonnes, a 75 CR deposit and 480 CR + 95 CR per full reachable quoted route leg + 80 CR per declared hazard tier. Its clock is zero, so the ordinary form is untimed. Authority: original-missions/original-families.md line 71 and matching original-families.json row; Root confirmed native units 4800 + 950*L + 800*H, separate 750 deposit, no default deadline.

## Scope and acceptance

Reserve exactly ScriptFreightGeneration.swift, ScriptOwnedCargoState.swift, ScriptFreight.swift, ScriptFreightCollections.swift, ScriptPack.swift and ScriptFreightVersionedSave.swift, plus ScriptBondedFreightTests.swift and paired notes. Add the exact profile/state ID; preserve the legacy profile, its generation and constraints. Keep existing three-row/six-draw board structure. Each new-profile declaration must explicitly provide three bounded nonnegative bondedHazardTiers. Freeze selected route leg count and declared row hazard in bondedQuote, verify L against every leg of the actual reachable selected path, and verify H against the declaration. Never infer a hazard/government taxonomy.

The existing contract confirmation debit and settlement authority own money. The actual owned cargo issue, partial deliveries, loss and durable publication continue through existing authorities. Successful settlement returns reward plus deposit once; failed/abandoned jobs pay zero. Nil deadline must allow native loss and abandonment while forbidding expiry.

## Validation and compatibility

Focused Swift sources are AUTHORED UNRUN in the restricted MBA lane. G1 must compile, run focused tests plus existing freight acceptance/persistence/custody regressions and make ci. The new fields are optional and absent for legacy plans; old legacy generator output remains unchanged. The new exact profile requires explicit quoted inputs and cannot silently inherit legacy tuning.

## Linked work and limits

PR-g03-bonded-freight-profile.md; ledger MBA-01; M05/G03. No GitHub issue or PR exists. This packet supplies the reserved native profile seam, not a packaged playable mission. The content integrator must supply approved production hazard tiers and a pack that displays and uses the native exported deposit/route_legs/hazard_tier fields; the sample test tiers are fixture data only. No timed variant is enabled because no approved duration and arming receipt exist. No second escrow, cash writer, cargo ledger or clock is introduced.

## Revision 2 independent review fixes

G2 found that the original packet could not load its actual TOML declaration and could not pass the actual versioned save preflight. Root reserved ScriptPack.swift and ScriptFreightVersionedSave.swift in addition to the original four production paths. The loader now admits the declaration field and existing closed-profile validation still rejects it on the legacy profile. Versioned preflight permits exactly the bonded 23-key plan shape only for the exact profile, requires a three-element hazard array and exact two-field non-null quote, and preserves the legacy 21-key shape. Existing typed decode and cold/native validation remain mandatory.

Two additional test functions exercise six actual pack-loader refusals and a real native board/issued-job ScriptSaveStore roundtrip with deposit debit-once and 18 rehashed chunk corruptions across contracts and missions. These supplement the original six methods. Revision 2 is REVIEW PENDING and EXECUTION PENDING, not ready for integration. MBA test execution was attempted once and stopped before compilation with Xcode license exit 69, zero executed tests, 0.40 seconds. Root/G1 reserved a local isolated focused executor after the M01 lease closes; the author retains test and fix ownership. No license acceptance or unchanged retry occurred. The original packet and hashes remain unchanged.

## Executed focused result

Local lease 748 on commit 53e6c10f21a0d1f5c9296f7839cd43650af8c0ac executed and passed all eight MBA-01 methods, including actual loader and native versioned board/job save roundtrip plus rehashed corruption refusals. The combined 19-method run failed only the separate MBA-04 timer-event JSON equality regression. Subsequent MBA-01 Swift changes are mechanically verified formatting only; all owned source and notes pass Swift formatting and Markdownlint. MBA-01 playable content, full project gates and native-consumer completion remain separate.
