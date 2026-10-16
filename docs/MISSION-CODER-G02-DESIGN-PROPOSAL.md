# G02 native courier design proposal

## Review state and authority

This is a source-only proposal for Researcher review through Orchestrator. No courier implementation, executable validation, native proof, capability advertisement or engine-completeness claim accompanies it. Proposed names and policies below require that review before implementation. Design base: `880d3a65478ed9304cc926fc21fbf3db9bf6d140`, including the accepted G21 integration.

The [assigned brief](MISSION-CODER-G02-DESIGN-BRIEF.md) and [frozen authority](mission-specifications/g02-research-authority.json) govern this packet. Authority SHA-256: `1b07c1423c8b2f7357358f4f5ebc815d3f605ac8edb0b728aafa04f2074b897c`. The snapshot records the source paths, hashes and research references. `PROJECT-SPACE-G02-1` is a project adaptation. All numerical terms must remain visibly labelled **PROJECT ESTIMATES**, without a claim to recovered server generation or live-server parity.

## Frozen terms and proposed lifecycle

| Difficulty | Base reward | Acceptance-relative duration | Variants |
| --- | --- | --- | --- |
| 1 | 500 CR | 172800 game seconds | Encrypted data, sealed package |
| 2 | 750 CR | 172800 game seconds | Encrypted data, sealed package |
| 3 | 1000 CR | 259200 game seconds | Encrypted data, sealed package |

Reward is `(base + 300 * frozen shortest-route hops) * 10` integer decicredits. Data uses zero tonnes; the protected package uses exactly one tonne. There is one unique item per accepted offer, no deposit, failure fee, encounter bonus or mission kill payment. Independent native bounties remain independent.

Proposed project policy: one authored provider, one shared exclusive group `g02-courier` across stations, variants and difficulties. Generate six rows in order `data-1`, `package-1`, `data-2`, `package-2`, `data-3`, `package-3`. Each row draws its own destination; equal destinations across rows are allowed. An active or suspended job blocks another acceptance from this provider, including when its content is missing. Terminal jobs retain receipts but release exclusivity. Decline consumes that row for the saved epoch; completion, failure and abandonment consume the accepted row permanently. Another row or a later epoch has another offer/item identity. No terminal item can be resurrected.

Use the existing station/content board cache, offer UUID namespace, job identity, quotes and painted-control proof. Proposed refresh period is 3600 seconds of the new menu-excluding clock described below. Reopening does not refresh within an epoch. A stale review must return to a newly painted board before acceptance. Refresh cannot alter an accepted job. If no route candidate exists, return a clear unavailable result without a board or RNG mutation; native refuelling/refitting may make the first generation possible in that same epoch. Once any six-offer snapshot is published, changes to fuel, fit, completion or reopening never regenerate that snapshot. Rows with insufficient present fit or reach remain visible and disabled with a reason; no usable offer means no acceptance.

## Shortest routes and deterministic generation

Add a bounded, pure route planner for this profile rather than using the weighted `NavigationGraph.path`. Its inputs are the actual current chart, ordinary systems, fitted native jump cap, tank capacity and current fuel, captured with the generation proof. Support charts 0 through 7, systems 0 through 255, actual main orbital origin/destination only. Exclude synthetic Plugh, secondary stations, inter-chart travel and same-system delivery.

Proposed project route policy: FIFO breadth-first search, neighbours ascending by stable system ID, maximum depth three. An edge uses `StarSystem.distance(to:)` and the native jump limit. The first edge must satisfy the actual current `maximumJumpDistance`; later edges may use `min(jumpCap, fuelCapacity / 10)` assuming an ordinary station refuel. This selects the lexicographically first minimum-hop path for ties. Candidate destination IDs are sorted ascending after the search. The plan stores the full origin-through-destination path, native edge distances and generation reach inputs. Current fuel is not silently replaced with full fuel; later refuelling is an explicit assumption, costs the player's actual money and is never granted by the mission. Affordability of every future refuel is not guaranteed by the quote.

No additional navigation computer is required by this profile: intrinsic hull reach remains valid. Fitted navigation equipment can extend reach only through the existing native healthy-fit projection. Missing/damaged equipment must either reduce that projection or reject an invalid commander; no mission-only equipment repair, loan or virtual capacity. Unlimited-fuel mode is not a generation input that substitutes for actual fuel; a real native refill already reflected in commander fuel can affect a later first generation or acceptance. Unlimited cargo does not create physical mission hold.

At confirmation, recheck the frozen first edge against actual fuel and every remaining edge against the current fitted cap/tank, plus real hold. Do not pick another route. An accepted route is the frozen quote/reward basis, not a mandatory tour: delivery requires the actual destination, item and contact. Alternative native travel is allowed and cannot change the reward. After acceptance, a hull/equipment change may make that advisory route temporarily infeasible; retain the item and deadline, show a refit/refuel warning and let the player recover through native actions. Hull change still must fit all held mission cargo and passengers, with no free missiles or item replacement.

Use the existing board hash-derived UInt64 seed as input to a separate native G02 generator. Its initial UInt32 is the low 32 bits, mapping zero to `0x6D2B79F5`. Store generator revision 1, initial/final UInt32 state and each row's pre/post state and selected index. For each of the six rows, advance exactly once with wrapping UInt32 operations:

```text
state ^= state << 13
state ^= state >> 17
state ^= state << 5
unit = Double(state) / 4294967296.0
index = floor(unit * Double(candidateCount))
```

Persist the sorted candidate IDs and canonical routes in the board's generation proof, bounded to 255 destinations and four IDs per route. Native generation constructs the terms/proof; the authored generator receives a read-only plan and supplies the six bounded descriptions. Reject a missing/extra row, changed terms, substituted destination, route, identity or draw. Existing providers retain their LCG. Initial seed, all draws, paths, IDs and terms are frozen, including after content absence. Saved proofs can be structurally and algorithmically revalidated from their frozen inputs without requiring the old hull still to be fitted.

## Proposed typed boundary

Add `courier-contracts-basic-v2` and `mission-calendar-v2` only when executable support exists. Keep the current manifest/API generation with optional guarded declarations, subject to owner review. Proposed manifest `courier` fields are `profile = "PROJECT-SPACE-G02-1"`, `generatorRevision = 1`, `deliveryContact = "courier-delivery"` and `abandonContact = "courier-abandon"`. The profile fixes terms; authors cannot override money, hold, clock or loss policy. Proposed contact labels are Courier Receiving Officer at the frozen destination and Courier Dispatch Officer at the frozen origin.

| Native type | Retained purpose |
| --- | --- |
| `ScriptCourierGeneration` | Revision, initial/final state, reach inputs, sorted candidates and routes, six draws |
| `ScriptCourierTerms` | Profile, variant enum, difficulty, frozen route/destination/contact and generation binding |
| `ScriptCourierCustody` | Item UUID, offer/job/content/origin binding, one issue receipt and held/terminal state |
| `ScriptCourierTerminalReceipt` | Delivered, expired, abandoned or native physical loss; causal time, operation identity and payment binding |
| `ScriptMissionCalendar` | Optional persistent menu-excluding clock projection, origin and last native adjustment binding |
| `ScriptCourierPreview` | Read-only difficulty, variant, route, hold, frozen reward, duration and fit issues for existing quote/UI |

Place optional generation proof on `ScriptContractBoard`, terms on `ScriptContractOffer`, optional deadline policy on `ScriptContractJob`, and optional custody on its `ScriptInstance`. Item ID is a deterministic native namespace of the unique offer/job/profile; it cannot be authored or supplied by a dialogue. Receipts bind provider/version/digest, exact job/item/offer, stations, contact and cause. Keep one issue and at most one terminal receipt per job, within the existing bounded instance budget. Reject exhaustion without evicting evidence.

Proposed authored commands: `courier.issue`, `courier.deliver`, `courier.abandon`. They name their local command receipt only, not arbitrary money, item IDs or timestamps. Issue is legal only inside the native accepted-event admission for that exact frozen offer. Deliver requires the real currently presented `courier-delivery` dialogue, its token/revision, actual destination main orbital, held matching item and native confirmation admission. Proposed abandonment policy is explicit confirmation of `courier-abandon` at the original offering main orbital, using the same native dialogue proof and default Back. Asking for a contact, Back or closing a view is insufficient. Restore exact content before using its authored abandonment contact; native expiry/loss do not require content. Terminal notifications are observers, not authority to issue, deliver or lose items.

Use the G21 pattern of a closed profile command surface. Permit its required journal/milestone/dialogue operations and typed courier operations; reject generic credit changes, protected-payload substitution, arbitrary timers/failure causes and receipt-free `mission.finish`. Acceptance must return with exactly one held native item. Delivery must return with exactly one matching terminal receipt and settlement. Deferred or omitted issue/delivery commands fail the complete proposal rather than leaving a partially accepted or paid job. Shared mission finish/settlement validates the native courier receipt while retaining ordinary objective guards.

Physical custody projects onto one reserved payload key in that same instance with value exactly one while held, zero/absent when terminal. Data has a typed held item and no payload quantity. Enforce both directions: a held package requires its exact projection, and a reserved courier payload cannot exist without its item. Other payloads cannot satisfy delivery. Generic cargo commands cannot mutate the reserved key. Acceptance checks `standardCargoCapacity - cargoTonnes`, including fitted passenger hold and every other protected payload; data accepts with exactly zero spare tonnes. Over-capacity virtual cargo cannot make an otherwise invalid physical fit valid. Existing inventory and hull transfer remain authoritative; no market commodity or second inventory is added.

## Menu-excluding clock, equality and delayed events

Source evidence requires an additive clock: existing `calendarActive` advances docked status/market/equipment menus, and existing tests deliberately expect docked status time to advance. Existing contract success requires `< deadline`; generic timers fire at `<= due`. Changing any of these defaults globally would alter accepted packs.

Propose `ScriptClockDomain.missionCalendar`, backed by optional `ScriptMissionCalendar` in `ScriptEngineState`. First G02 board preparation initializes its value from the existing calendar once; subsequent saves retain it. It advances by the same clamped native simulation delta only during unpaused actual flight simulation with menu screens excluded. Docked menus, Gallery, review/contact pages, pause and unloaded wall time contribute zero. Use an explicit screen predicate, shared by runtime and tests, rather than equating all undocked screens with flight. The existing calendar stays untouched.

Mirror actual admitted native calendar adjustments into this projection: launch adds the existing 600 seconds once; actual completed hyperspace adds the existing admitted source-distance-squared travel time once. Preserve the existing separation between native fuel distance and O08 calendar distance. Share operation identity, pending journey reservation and overflow checks; do not charge a canceled jump. Current refuel/market/equipment transactions have no simulated service duration, so charge zero rather than inventing one. Any future timed service must use the same native adjustment hook; adding such a service is outside this packet. All mirrored durations are project timing policy, not evidence of server parity.

Set job `acceptedAt` and `deadline = acceptedAt + duration` from this clock in the acceptance candidate. Proposed `deadlinePolicy = inclusiveConfirmation` is legal only with validated courier terms. Nil retains all old contracts' exclusive policy. `ScriptContractJob.valid`, snapshots, quote checks, native finish and settlement must use the same policy and clock. Completion at equality succeeds; expiry uses strictly `now > deadline`.

Use a native courier expiry sweep after native clock adjustments and before new courier actions, plus after frame advancement and load. Do not install a generic once timer at the deadline or use floating-point `nextUp` as a workaround. Sweep only active courier custody and atomically settle zero-payment failure with a typed expiration receipt. It must work with missing/suspended content: expiry and native loss are ownership safety rules, not Lua handlers. At equality the job remains held; the next representable native advancement beyond the boundary expires it.

Proposed causal policy: handoff is synchronous within the existing native confirmation command. Capture its clock at actual confirmation, validate custody/location/token there, evaluate `courier.deliver` inline and publish consumption/receipt/payment together before another simulation advancement can interleave. An observer processed later sees the frozen terminal receipt and cannot pay again. A delayed `station.docked`, `dialogue.confirmed` lookalike or timer event is insufficient to complete: at a later clock the expiry sweep wins unless the real confirmation already committed. There is no saved pending handoff reservation that pauses the deadline. A queued event claiming an earlier cause time cannot backdate payment. Validation must cover genuine equality confirmation with later observer processing, a pre-deadline dock followed by a late confirmation, and a forged/deferred earlier timestamp. The receipt's causal time, not a later observer's processing time, records a successful handoff.

## Actual physical loss and failure atomicity

The current successful `Game.escapePod` clears ordinary cargo but preserves scripted protected payloads. There is no ordinary package-jettison transition to reuse. Propose the smallest actual loss integration: successful native escape-pod use destroys the abandoned ship's held physical courier packages, and the transition from a live ship to native game-over destroys held physical packages. No arbitrary `courier.lose` command or forged actor event is accepted. Mere damage, equipment damage, hull exchange and unsuccessful escape-pod attempts do not destroy an item.

Proposed project policy: encrypted data travels with the commander and survives an actual successful escape pod. Fatal game-over does not create a recoverable digital delivery path; starting/loading a commander keeps the existing native game/save semantics. Do not invent a post-death data recovery feature. Expiry and abandonment terminate either variant. Loss terminates only the affected physical jobs, consumes only their reserved hold and records zero success payment. All unrelated cargo, equipment, passenger custody, native bounties and other mission state remain governed by their existing native action.

For escape-pod commands, include loss receipts and terminal cleanup in the existing command candidate and publication. For fatal simulation, retain the existing rule that physical facts commit before script publication. Record a bounded native pending loss fact on the affected custody immediately, making delivery impossible; propose terminal cleanup through the existing publisher. Publication failure keeps that physical fact/pending loss in memory for retry and leaves the previous durable generation intact. Never undo a real death or claim an unpublished loss survived a process restart. Persisted pending facts must validate their operation/item/origin, cannot be script-created and must resolve before delivery after load. No content callback is needed for loss or cleanup.

Acceptance publishes offer consumption, job, frozen clock/policy, issue receipt, item and physical projection in one existing save generation. Handoff publishes exact contact confirmation, item consumption, terminal receipt, mission outcome and native wallet payment in one generation. Failure/abandonment similarly publish only owned cleanup and zero-payment settlement. Save failure restores the previous command state, including the presented review/handoff, without duplicate IDs or payment. Physical simulation follows the separate fact-first rule above. No alternate save controller, wallet, finance ledger or equipment subsystem is introduced.

## Save and Gallery compatibility

Propose writer format 21, readers 2 through 21, using the existing commander/missions/world chunks. Optional fields preserve genuine old saves without inventing custody, terms or clock history. Reject a pre-21 version claim or unversioned raw Commander that contains new courier fields, clock state, deadline policy or domain, including concealed nested generation/receipt fields. Extend existing raw/version guards and JSON preflight bounds rather than relying on unknown-field dropping. Verify global item/receipt uniqueness, terms/board/job identity equality, route/draw proof, finite clock/deadline, exact payload projection, terminal payment and pending-loss consistency before publishing any load. This is integrity validation, not a claim that unsigned save files are cryptographically authenticated.

Missing exact content retains all terms, item fit, clock and receipts. Delivery and the authored abandonment contact stay unavailable until matching content returns; expiry/loss cleanup still executes natively. Content updates cannot substitute another digest or silently reissue the item. The quote retains full isolated acceptance simulation, resources/epoch binding and native revalidation; normalize only autonomous clock progress in quote resources, while never normalizing custody or physical capacity.

Gallery briefing/progress/outcome uses typed terms/custody/receipt: difficulty, variant, destination, named contact, item identity, real hold, route assumption, reward, remaining game time, terminal cause and paid amount. Proposed trials open the ordinary unaccepted board review with Back selected, with all six choices reachable. Preserve `constructScriptTrial` returning before `prepareScriptTrial`, private scene resources and preparation before namespace/save/parent/runtime publication. No preissued item, teleported arrival or scripted success proof. Both variants need actual acceptance, native travel, destination contact and save/reload proof. Preserve live commander/save/preferences on Start, Save, Load, Restart, Return and rejected preparation. The Inventory Start/Return epoch hook remains a separate mandatory composition requirement; this packet cannot claim it implemented.

## Exact proposed source boundary

Paths in this table are the complete proposed implementation allowance. New helper names are proposals; any additional source path or broader shared rewrite requires review through Orchestrator.

| Path | Allowed change |
| --- | --- |
| `Sources/EliteCore/ScriptCourierState.swift` (new) | Closed profile/variant, terms, generation, custody/receipts, bounded cross-field validation |
| `Sources/EliteCore/ScriptCourierGeneration.swift` (new) | Pure bounded BFS, xorshift32 and frozen native six-row plan |
| `Sources/EliteCore/ScriptCourier.swift` (new) | Issue/deliver/abandon admission, preview, native expiry and physical-loss settlement helpers |
| `Sources/EliteCore/ScriptMissionCalendar.swift` (new) | Optional clock state and menu predicate/adjustment projection |
| `Sources/EliteCore/ScriptPack.swift` | Optional courier manifest, exact key/profile validation, two guarded capabilities |
| `Sources/EliteCore/ScriptMissionState.swift` | Optional custody/calendar fields, added clock domain, bounds/validation/clock lookup |
| `Sources/EliteCore/ScriptContractState.swift` | Optional board proof/offer terms/job policy, receipt-dependent settlement validation, courier quote preview and clock-only normalization |
| `Sources/EliteCore/ScriptContractCore.swift` | Courier-only generation/admission branch; reuse board IDs/cache/quotes/native settlement; leave other generators unchanged |
| `Sources/EliteCore/ScriptCommands.swift` | Three typed command dispatches, closed courier restrictions, receipt/policy-aware shared finish |
| `Sources/EliteCore/ScriptDirector.swift` | Read-only courier snapshot, typed Gallery detail/missing-content summary and new clock progression; native contact confirmation admission/default Back; preserve old timer equality |
| `Sources/EliteCore/ScriptCalendar.swift` | Mirror successful launch/jump adjustments with joint overflow/reservation checks |
| `Sources/EliteCore/Game.swift` | Actual successful escape-pod/fatal-transition hooks, runtime expiry retry/order and raw-load guard only |
| `Sources/EliteCore/ScriptPersistence.swift` | Format 21, legacy-version rejection and load integrity |
| `Sources/EliteCore/ScriptSaveJSONPreflight.swift` | Bounds/raw presence guards for new nested data |
| `Sources/EliteCore/ScriptGalleryTrial.swift` | Courier-only unaccepted review preparation after construction |
| `Sources/EliteCore/ScriptCampaignGallery.swift` | Include courier custody/outcome detail in existing painted Gallery target proof |
| `Sources/EliteCore/ContractBoardDisplay.swift` | Courier terms/fit/estimate/contact review text within existing renderer |
| `Sources/EliteCore/ScriptContractPageInput.swift` | Include typed courier review identity in existing painted proof, if not already covered by offer identity |
| `docs/mission-packs/generated-couriers/manifest.toml` (new) | Single closed G02 provider, all six rows, named contact, isolated trial scene |
| `docs/mission-packs/generated-couriers/scripts/main.lua` (new) | Six text rows from native plan, journal/milestones, destination dialogue and typed commands |
| `Tests/EliteCoreTests/ScriptCourierTests.swift` (new) | Issuance/delivery/loss/fit/atomicity and six-combination native fixtures |
| `Tests/EliteCoreTests/ScriptCourierGenerationTests.swift` (new) | Exact draws/wrapping/zero seed, bounded routes/ties/no candidates and frozen lifecycle |
| `Tests/EliteCoreTests/ScriptCourierPersistenceTests.swift` (new) | Save corruption/legacy/content absence and publication failures |
| `Tests/EliteCoreTests/ScriptCourierCalendarTests.swift` (new) | Menus/pause/native adjustments/equality/late cause, old-contract regression |
| `Tests/EliteCoreTests/ScriptCourierGalleryTests.swift` (new) | Two-phase trials, painted controls, actual runtime isolation/restart/return |
| `docs/SCRIPTABLE-MISSIONS.md`, `docs/SCRIPTABLE-MISSION-STATUS.json`, `README.md` | Actual supported API/profile/format/status only after implementation; no whole-engine-ready claim |
| `docs/ISSUE-generated-couriers.md`, `docs/PR-generated-couriers.md`, `docs/MISSION-CODER-G02-DESIGN-PROPOSAL.md`, `docs/MISSION-CODER-G02-VALIDATION.json` (new where absent) | Owner-reviewed design, issue/PR handoff and immutable validation record |
| `docs/images/` (new G02 captures only) | Actual renderer/native captures under a granted validation slot |

Do not edit `NavigationComputer.swift`, navigation weighting, finance, general equipment, collision/motion adapters, AppKit ownership, existing courier sample semantics or unrelated pack timing. Existing protected inventory/fit APIs are consumed rather than replaced. A required UX change outside the listed renderer/proof/Gallery paths must be routed through Orchestrator before expanding the boundary.

## UX request through Orchestrator

Ask UX Designer to review the existing board review and Gallery presentation for these concrete requirements: six clearly identified difficulty/variant choices; 0t versus 1t; destination and named contact; shortest-hop reward and explicit later-refuel assumption; actual fit/reach issues; acceptance-relative game-time duration; **PROJECT ESTIMATES**; default Back; explicit Accept/Deliver/Abandon; held/delivered/lost identity and remaining time; failure cause and paid amount. Back, menu close and wrong-station contact must not mutate custody. Trial review must expose both variants and all difficulties without granting completion. Retain the current painted keyboard/pointer/menu proof and viewport/epoch checks. UX authorizes presentation, not weaker native evidence.

## Validation and delivery gates

This design ran no build, test, app, simulator, media or full-CI command. After owner review and an explicit validation lease: exercise all six actual native accepts/travel/handoffs; xorshift zero/nonzero/wrapping fixtures; ties/no candidates; exact 1t fit/one tonne short/data at full hold; wrong origin/destination/contact/item, duplicate confirmation/replay; missing/damaged fitted reach; reload/content absence/hull transfer; Back/decline/exclusivity/refresh; equality/one-step late/delayed cause; real successful/failed escape pod and fatal loss; corrupt saves and failed acceptance/handoff/loss publication. Verify ordinary contracts keep exclusive deadlines and G21 full quotes/two-phase preparation remain intact.

Record source/input/save fingerprints and actual durations, retain failed evidence and native originals, then run complete `make ci` coverage/sanitizer/leak gates under the granted slot. Generate README media only through `make readme-media` when requested for the final validated packet. Gallery live-state isolation and the Inventory epoch composition remain explicit integration gates. Source-owner acceptance, central local integration, actual PR `@codex review` until clean, final-head checks and central merge are distinct gates. No independent push, PR or merge is authorized for this packet.
