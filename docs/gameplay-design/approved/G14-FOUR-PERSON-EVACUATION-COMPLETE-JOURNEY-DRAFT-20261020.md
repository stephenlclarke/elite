# G14: complete four-person orbital evacuation journey

Draft for Root's queue decision, 20 October 2026. G08 is the approved predecessor after qualified G05 integration. This is design only: no implementation, runtime job or canonical ledger change.

## Authored requirements

**G14 / M09 / F33 / F35 / K04 / K09**: `l337.contract/orbital-evacuation`, Registered orbital evacuation.

Authority is the exact template in this workspace's original-missions/original-families.json and Markdown counterpart, plus original-missions/ENGINE-CONTRACT.md. The existing G04 qualified journey and approved G08 handoff supply reusable principles, not evidence that G14 already works.

- Four registered, living, consenting survivors and four actual fitted berths.
- Zero additional cargo tonnes, deposit and donation; untimed ordinary offer.
- Visible actual fitting, consent and reachable space-station endpoints; no hidden rank, external campaign progress or imported score gate.
- Reward **940 + 125L + 80H CR**.
- Bring the same consenting people to the verified receiving berth; preserve real losses.
- Commit actual reception, advertised settlement and first-success clue **orbital-evacuation-family-trace** together, once.
- A repeatable family may use genuinely available new sources; a failed retry never restores destroyed people or clones an old group.

The authored template does not require capsule recovery, a recorder, station destruction, an emergency countdown or Shattered Wake campaign progress. Those are not extra conditions for this ordinary G14 journey.

## Proposed defaults for approval

Use actual **Avenor G0/S7 main orbital -> Renas G0/S185 main orbital**, with its already exercised ordinary one-leg route. Freeze native reach/path at the live quote rather than assuming every fitting can fly it. Proposed L1/H0 pays **1065 CR / 10650 native**.

The source is a registered four-person group temporarily housed at the departure station. The proposed incident is an announced evacuation of a residential wing for a life-support overhaul. No failing station simulation, made-up physical casualty event or station death receipt is required. Describe it honestly as this finite registered evacuation.

Proposed native source batch: **avenor-orbital-evacuation-01**.

| Stable person key | Display name |
| --- | --- |
| sera-venn | Sera Venn |
| tavi-noll | Tavi Noll |
| eren-pell | Eren Pell |
| mara-quill | Mara Quill |

All four initially live with the actual Avenor station custodian and independently request safe transport to Renas. They are not G04 passengers, G08 rescuees, EMP crew, generic ScriptPassenger copies or an abstract headcount.

This first complete delivery uses one finite source group. Do not advertise unlimited repeats or mint a new batch on every offer refresh. A later repeat needs a separately approved, genuinely new available source; that future population provider is outside this batch.

## Complete player journey

1. **Review evacuation.** At actual Avenor, the normal station contract board shows all four names, agreed Renas receiver, four required working compatible cabins, zero extra cargo, no deposit/deadline and the frozen route/reward. Reading or backing out changes no custody, cabins, cash or clue.
2. **Request group.** A deliberate normal Confirm requests the evacuation party through the actual station provider. Register the finite native roster once, retaining its station actor, source custodian and individual destination requests. Publish through the current durable candidate/writer. Reopening, reload or reinstall finds those same identities.
3. **Receive native replies.** The native provider evaluates each actual person's current transport request against this carrier, four distinct available compatible life-supported berths, agreed destination, fitting revision and current source dock. It produces individual accept/refuse/withdraw replies. Player Confirm and Lua data cannot assert consent.
4. **Board four.** A visible Board evacuation group action revalidates the quote, route, four replies and four actual berths. One actor transaction accepts the job, reserves/occupies the exact four cabins, admits those same four native references and commits boarding evidence. Fewer than four valid replies/places boards nobody. No free cabin, virtual person or hidden cargo slot.
5. **Carry those people.** Actual launch, native flight/jump and actual Renas docking preserve their identities, living state and occupancy. The normal mission log shows destination, aboard 4/4 and next action. A wrong intermediate dock alone changes no destination, custody or success state.
6. **Receive four.** At the actual agreed Renas receiving office, normal Confirm validates the same four living consenting references, original boarding, current native arrival context and actual cabin custody. Transfer exactly those people to the receiver, release exactly their four berths, close the job and commit 1065 CR plus the single G14 clue atomically. Acceptance, boarding, a generic arrival, partial care or another family's receipt pays nothing.

The departure and receiving interfaces use existing shared arrows, Confirm and Esc actions; no new keyboard shortcut. Explain a refusal with the actual missing cabins, incompatible/lost life support, destination request, stale fitting or unavailable route. Do not label a refused group as aboard.

## Native source and receipt boundary

Propose a closed NativeOriginalEvacuation source/state/board adapter in the existing native-person custody subsystem. Reuse the current station dock, berth, native reply and receiving mechanisms; do not replace them with a generic population framework or copy G04's source as authority.

The inspected G04 NativeStationPersonIdentity and definition are closed to its exact two names/batch and Avenor/Renas journey. G14 needs its own closed native identity/source branch, for example NativePersonReference.evacuation. That is a proposed implementation name, not an existing API. Do not widen G04's validation to accept arbitrary four-person rosters.

Identity derives from the existing native world owner, actual source station, finite source batch and person key. It does not derive from a new mission instance, offer index, visit, pack digest or retry. Preserve identity across source updates; a digest mismatch may refuse an unsupported pack but cannot replenish the people.

Registration, consent and boarding evidence bind the original source, actual dock/station actor, carrier, person request and reply revisions, four distinct actual berth IDs, inventory revision, native operation/epoch/time and accepted job. Preserve the current custody admission/transfer history and one current custodian per person. A data manifest is zero-tonne metadata, not a substitute for living people or a new physical crate.

Actual receiving uses current native main-station arrival/publication authority and joins the same source, boarding, four people and held cabins. It cannot be forged by setting a mission parameter, replaying an earlier arrival or counting four unrelated station passengers.

## Cancellation, losses and publication

Before boarding, refusal/withdrawal or cancellation leaves the original group with its genuine source custodian and boards nobody. Request/offer history is retained; it is not a source reset.

After boarding, cancellation is a deliberate actual return to the source receiver with custody and cabins transferred together, no payment or clue. If the existing safe-care policy supports a different actual station, expose that as a genuine non-successful discharge, not the agreed Renas completion. Do not invent remote deletion of passengers. A custody transfer to the wrong receiver prevents later successful full-party settlement.

Any actual person death/loss remains permanent. Partial rescue/care can preserve surviving people but cannot replace missing members, collect the full reward or grant the clue. Never create replacement survivors to unblock this incident. Existing occupied-berth escape refusal and fitting/trade restrictions remain in force; do not weaken them to manufacture a loss case.

All durable mutations use the existing candidate/writer. Writer refusal at roster registration, offer/reply publication, boarding, return/care or final reception preserves the previous committed source/custody/cabins/cash/clue state. Real irreversible death still remains real. A retry cannot duplicate admission, move a person twice or add a second reward/clue.

## Proposed ownership: 23 paths

Root should reserve the exact necessary hunks after G08 qualification/integration. G3 is the isolated implementation owner; G1 alone integrates and publishes. Do not edit canonical source or overlap active G08/G05 reservations. Drop unnecessary paths at preflight; report any demonstrably needed extra path to Root before editing.

Three new implementation files:

- Sources/EliteCore/NativeOriginalEvacuation.swift
- Sources/EliteCore/NativeOriginalEvacuationBoard.swift
- Sources/EliteCore/NativeOriginalEvacuationSave.swift

Fourteen existing bounded source/consumer/save files:

- Sources/EliteCore/NativePeopleState.swift
- Sources/EliteCore/NativePeopleRuntime.swift
- Sources/EliteCore/NativePeopleStation.swift
- Sources/EliteCore/NativePeopleVersionedSave.swift
- Sources/EliteCore/ShipAccommodation.swift
- Sources/EliteCore/PassengerCustody.swift
- Sources/EliteCore/ScriptPack.swift
- Sources/EliteCore/ScriptCommanderQuery.swift
- Sources/EliteCore/CommanderCargoValidation.swift
- Sources/EliteCore/ScriptPersistence.swift
- Sources/EliteCore/ScriptSaveJSONPreflight.swift
- Sources/EliteCore/ScriptBundledPacks.swift
- Sources/EliteCore/ScriptBaseClueCatalog.swift
- Tests/EliteCoreTests/BundledScriptPackTests.swift

Six new qualification/content/notes files:

- Tests/EliteCoreTests/NativeOriginalEvacuationTests.swift
- Tests/EliteCoreTests/NativeOriginalEvacuationSaveTests.swift
- Sources/EliteCore/Resources/ScriptPacks/l337-orbital-evacuation/manifest.toml
- Sources/EliteCore/Resources/ScriptPacks/l337-orbital-evacuation/scripts/main.lua
- docs/ISSUE-original-orbital-evacuation.md
- docs/PR-original-orbital-evacuation.md

Actual post-G08 source preflight must identify source-case exhaustiveness and every production board/query/custody/berth/save caller affected by the new branch. The list is prospective, not a claim that another Game/contract-board helper never needs a bounded hunk. Reserve that exact hunk with Root if necessary; do not add an unreviewed general dispatcher.

## Proposed current saves

Propose **47 Normal / 48 Alien**, subject to Root's reservation after approved G08 45/46. Persist the finite source and native replies even before boarding, four original references, custody/berths, actual death/transfer, accepted job and terminal reward/clue receipt.

A genuine G14-only state must validate independently. Composed G02/G04/G05/G08/G14 claims must each retain their own genuine evidence; sharing an envelope never supplies a missing feature claim. Validate G14 both without and with genuine alien attachments. Do not fabricate G08/G04 progress to select a newer version.

Older envelopes remain strict and reject G14 fields/source claims. Keep existing current-feature selection and raw/null/duplicate/foreign identity validation. No predecessor-format migration, old-schema widening or general save redesign is proposed.

## Focused owner acceptance

1. Finite exact four-person roster at the genuine departure station; review/Back changes nothing, and repeated request/reload/reinstall never restocks it.
2. Actual individual native accept/refuse/withdraw joins. Player-authored consent, foreign person, wrong destination/carrier, stale replies or fitting refuse without partial boarding.
3. Three valid berths refuse; four distinct genuinely free compatible working berths admit exactly the original four. Zero extra cargo is required; no free fitting or capacity grant.
4. Full real departure/flight/arrival/receiving journey pays 1065 CR and the G14 clue once, transfers the same four people and releases their exact berths. Wrong, partial, dead, unrelated or replayed reception cannot complete.
5. Actual return/care/cancellation and authentic loss preserve census, surviving custody and truthful non-success; no clone, hidden payout or repeated clue.
6. Actual publication refusal/retry at registration, consent, boarding and final return/reception conserves complete source/custody/berths/receipts/cash/clue without undoing physical death.
7. Normal/Alien cold reload before boarding, during carriage and after terminal retains genuine G14-only and composed claims. Missing/duplicate/foreign/stripped provenance and new fields under old envelopes refuse.
8. Actual production pack CLI/digest and meaningful owner-focused unit PASS, then one independent review of the complete frozen bugs/performance/style boundary before G1 integration. No broad suite, unchanged passing-cohort rerun or playable milestone claim is implied.

## Root decisions

Approve or amend the ordinary source/receiver, residential-wing evacuation context, four names/batch, L1/H0/1065 CR, finite initial group, all-four atomic boarding and actual return/non-successful care policy. Reserve the current save pair and prospective ownership after G08.

The new source branch must be wired to actual station/cabin/receiving authority. Precise post-G08 caller names and any additional source-case hunk remain bounded implementation preflight decisions, not reasons to delay this complete draft.

G14 remains design queue work until Root assigns it after G08. No later successor is assigned by this file.
