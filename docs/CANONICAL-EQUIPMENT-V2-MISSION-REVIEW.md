# Canonical equipment v2 mission compatibility review

Source-only owner review on16October2026. Accepted Mission runtime is `d12311d8fca20277aefc150f487acafb7377b0e4`, with documentation-only follow-ups. The provider contract inspected central `94d2f88647b54fda30653b41010d3da73a41d24d`; MC1's consumer map advances that inspection to `2b3857c7339280ed47469a16e46a41360b975925`. All nine consumer-map central source fingerprints were independently checked against immutable Git blobs. No code, build, test, native session, save or preference mutation was performed.

| Reviewed input | SHA-256 |
| --- | --- |
| `/tmp/elite-canonical-equipment-issue-contract-v2-20261016.md` | `3768053f8d4ffc1376f33bd3d0620eb8aa86c45db758af33c692e6413b9b49ea` |
| `/tmp/elite-mission-canonical-consumer-contract-current-20261016.json` | `819244f15cf8cd4ddab5030610193bbc2a81f64e68f739a1574624ea854503dc` |

## Ratified policies supported

Orchestrator has ratified one physical owner; immutable mission original IDs and nonphysical obligation references; finite physical standard ammunition and explicit virtual unlimited shots; lossless old-bag migration; once-only materialization of genuinely implicit free Basic foundations; explicit pinned atomic fit-all without foreign-loan removal, downgrades or partial fitting; restoration only of actual retained compatible displaced items; and central conflict-refusing hull transfer until an explicit storage plan exists. This review supports those decisions and does not reopen them. The contract resolves the earlier identity, retained condition/modification, ordinary-save promotion and Gallery epoch concerns in the required direction.

The existing deterministic issue ID algorithm, held default, ordered original indices, all-versus-remaining return, release without ownership recreation, bidirectional source validation, missing-content loan protection and whole-candidate publication remain necessary. Native pointer/container format21 is separate from canonical equipment version2 and issue-record version2. Exact field spellings and provider/application receipt shapes remain the coordinated G1/MC1 implementation seam; no second schema is proposed here. Implementation routing remains exclusively through Orchestrator to Mission Coder1 for Researcher-origin work.

## P1: courier reach snapshot is incompatible with current native statistics

Accepted `ScriptCourierGeneration.swift` creates `ScriptCourierReach` from the actual Commander getters, but validates revision `elite-880d3a-native-reach-v1` using `max(performance.jump, navigationTier.jumpCap)` and `min(jumpCap, fuel / 10)`. Current central `FuelStorage.swift` uses the fitted navigation component's effective `jumpReach` and `jumpFuelCost`. Earned navigation modifiers can raise reach beyond its nominal tier and reduce fuel cost below1. A legitimate new component fit can therefore produce a captured reach that the old courier validator rejects, preventing offer generation or making the saved terms invalid.

The later-leg graph and current acceptance checks also hardcode `min(jumpCap, fuelCapacity / 10)` instead of the actual `fullTankJumpDistance`. Even if initial validation is bypassed, that would lose fuel-efficient routes and disagree with the actual native travel contract. The current MC1 ready-file list omits these courier consumers.

Required narrow correction: include `ScriptCourierGeneration.swift` and `ScriptCourier.swift` in the MC1 composition boundary. Give newly generated offers an explicit new native-reach revision with enough frozen effective navigation/fuel facts to validate their original snapshot independently of the commander's later fit. Use actual `maximumJumpDistance` for the first leg and `fullTankJumpDistance` for refuelled later legs. Preserve exact v1 decoding, route reconstruction and validation for existing boards and accepted jobs; do not rewrite their destination, six draws, reward, deadline, route or identity. Acceptance rechecks current actual fit against the frozen route and may refuse after a refit. A new reach revision does not require pointer format22, a different random generator or a health subsystem.

## Existing-state details that must survive the adapter

Old `issuedEquipmentValid` requires every active unconsumed loan original to exist. It does not require an absent non-loan original to be fabricated or marked consumed retrospectively. Existing generic removal can leave such a valid historical non-loan issue without a consumption entry. Preserve those original IDs and the absence faithfully; do not invent physical items or native consumption receipts during migration. Return must still refuse an unrecorded missing original. The v2 validation wording should retain this precise distinction while checking every present original against its saved source/index/node.

An old held loan may already have condition below10000 or retained modifications: old validation allows that when held, even though fitting requires pristine state. Lossless migration must retain it and allow its own legitimate return; the new restriction on loan modification must not retroactively prevent returning already-retained originals. Basic foundation restoration may be needed only when an actual enhanced fitting is removed. If the retained Basic item is already fitted, do not duplicate or move it unnecessarily; if its saved displacement reference is missing or incompatible, reject the whole settlement without minting a substitute.

Accepted `PassengerCustody.swift` also references the old bag in trade-cargo and fitting exemptions, and calculates `commonEquipmentUnits` from native names. Include its adapter in the consumer audit: zero-unit intrinsic foundations must not become optional hardware charges, occupied berths/protected courier tonnes cannot be overbooked, and Executive behavior must follow the ratified native rules. This is a required existing consumer, not a new accommodation model.

## Necessary acceptance fixtures

| Case | Required evidence |
| --- | --- |
| Earned navigation reach/fuel modifiers | Actual valid graded/recovered native component generates and saves a new-revision courier offer; first/later leg reach agrees with native getters and costs. No unsupported fuel-efficiency values are invented for a fixture. |
| Existing courier proof after upgrade/refit | A genuine v1 frozen board/job reloads unchanged; a route that current fitting cannot traverse is refused without reroll, payment, clock or admission changes. Fuel-efficient current fitting is not reduced to the obsolete full-tank formula. |
| Existing personal equipment and multi-item issue | Same-name paid held/fitted items retain their IDs, grades, history and source; default issue remains held. One obstructed item in fit-all rejects every admission, displacement and issue receipt. |
| Foundation loan return | An enhanced loan displaces an actual retained Basic item; returning fitted or held originals restores only the needed compatible retained original. Already-fitted Basic is not duplicated. Missing/incompatible displacement proof causes atomic refusal. |
| Historical held and absent items | Non-pristine/modified held loan retains exact metadata and can be returned, but cannot fit/fire/grade; a historically absent non-loan original is not recreated or given a fictitious consumption receipt. |
| Physical and virtual consumption | A real loaded round uses the original highest occupied pylon ID; held rounds cannot fire. Unlimited use consumes no real original. Failed target, actor, queue or file admission preserves inventory, obligations, projectile/source, armed state, cooldown and ordinary effects. |
| Migration and save routes | Old-bag-only and canonical-v1-only migrate once; mixed representations refuse; explicit version2 empty remains empty. Capacity includes foundations and rounds. Missionless canonical state remains ordinary JSON; an already-loaded empty format21 save remains format21; missing-content loans remain protected. Full cross-ledger validation precedes header/chunk separation. |
| Accommodation and Gallery | Actual occupied cabins and protected courier hold reject overbooking; intrinsic foundations add no accidental units. Old typed Inventory commands refuse after successful trial Start/Restart/Return, while failed transitions preserve legitimate current actions and parent state. |

After exact provider/consumer agreement, review and validate the composed source, retain accepted script-state and trial/contract phase fixes, regenerate renderer assets, freeze and run complete `make ci` under the assigned exclusive slot. Formal PRs, including distribution tap changes, require `@codex review` until clean and passing required checks on the final head before merge. Main/release/Sonar remain the central owner's gates; full-engine readiness remains false.
