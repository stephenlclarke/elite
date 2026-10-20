# G08: complete non-EMP capsule rescue journey

Draft for Root's next assignment decision, 20 October 2026. G05 remains the
active qualification; M01 release work stays first. No implementation, runtime
job or canonical ledger change is performed here.

## Existing authority and authored requirements

**G08 / M09 / F33 / F35 / K04 / K09**, `l337.contract/custody-rescue`.
Authority: exact G08 template in `original-missions/original-families.json` and
.md in this design workspace; ENGINE-CONTRACT.md; retained
`/tmp/elite-g3-MBA07-native-producer-proposal/proposal.json`. That old proposal
is supporting design, not working code or a current save contract.

Authored: two registered living evacuees, two actual fitted berths, one tonne
for their unique emergency record, zero deposit/donation, untimed base. Reward
`900+120L+80H` CR. Recover their identified living capsules, obtain voluntary
boarding and complete real reception. Destroyed/empty/unrelated pods cannot
create survivors. Exact clue `custody-rescue-family-trace` once after full
successful settlement.

Reuse current G04/G05 native identity/consent/berth/receiving principles. Their
station-origin people are not these rescuees. The actual G08 gap includes finite
original capsule occupants, real collection, same-reference care-to-cabin
transfer and the original physical emergency record; a capsule-only SDK is not
this delivery.

## Recommended ordinary content: not previously approved

Reuse the retained proposal's source pair: **Cedamar G0/S85 → Celalen G0/S241**,
L1/H0, **1020CR / 10200 native** only at final reception. Two original people,
proposed retained names Neri Voss and Ilan Rook; finite batch
`cedamar-rescue-01`; exactly two occupied capsule actors and one unique
one-tonne record actor outside Cedamar. Author freezes current supported
capsule/cargo templates and collision-clear native poses before tests. Old
SH040/coordinate suggestions are not proof of current geometry or units.

Recommend this complete serial-care itinerary to honour the authored one-tonne
slot:

1. At Cedamar, review the entire incident/receiver/requirements/reward. Accept
   and initialise one finite native source atomically; reserve two real working
   compatible berths and the one cargo slot. No item/person is invented by the
   quote.
2. Actually recover original capsule A through the existing fitted rescue tool,
   native aperture/motion/capacity seal and publisher. Return to Cedamar and
   transfer that same living person/pod to actual native care. Its care receipt
   frees the pod tonne honestly; no mission reward or clue.
3. Recover original capsule B and perform the same actual Cedamar care transfer.
   Care of one person never substitutes for the other. The original identities
   and actual station custodian remain recorded.
4. Both original living people issue trusted native accept/refuse/withdraw
   replies for Celalen transport after care. Reuse G04/G05's policy checks and
   real fitted cabin machinery with a closed G08 source adapter. Both replies
   and two berths commit together; **same references**, not new station people
   or a second first-admission clone.
5. Recover the original physical emergency record last, using that one cargo
   slot. A new crate, ordinary commodity, Lua payload or another incident's
   record cannot substitute.
6. Actually travel to Celalen. Final receiving Confirm validates the same two
   living consenting people and original record, transfers their custody,
   releases berths/removes the record and commits 1020CR plus one G08 clue
   atomically. Intermediate care, record collection or arrival alone pays
   nothing.

Local rescue sorties add no interstellar legs; the quoted native path is one
Cedamar-to-Celalen leg. No new medical countdown, forced EMP attack, hostile
encounter or hidden qualification is proposed.

## Required capacity and consent decisions

The existing collector accounts for one protected tonne per sealed capsule. The
serial-care variant never carries both at once; it must let the exact G08
capsule temporarily fulfil its already-reserved one-tonne slot, restore that
reservation after actual care, then fulfil it with the real record. This is a
closed G08 reservation-use adapter, not extra free capacity or disappearing pod
mass. Author preflight must bind it to the current native collector; it cannot
charge pod plus unused reservation twice.

Root should approve serial care, or explicitly approve a differently advertised
pickup capacity before authoring. A batch capture requiring two pod tonnes must
not be described as fitting the authored one-tonne allowance. Do not silently
shrink pods or turn the physical record into zero-mass data.

Recommend native rescuees whose own recorded transport request is Celalen after
real Cedamar care. Emergency collection/care is not voluntary passenger consent.
Implement `NativeOriginalRescueJourney.replyToTransportOffer` against the
original live person, current actual care custodian,
carrier/berth/destination/request revision. Player Confirm/Lua cannot assert
yes; refusal/withdrawal boards nobody. G04's hardcoded station source cannot
simply authorise these references.

Care-to-cabin re-embarkation of the same already-cared reference is a real
additional adapter: retain initial capture admission and care history, add the
genuine boarding operation, derive one current custodian, then use actual final
reception. Do not reset old transfers, duplicate the person or claim this
operation already exists unchanged.

## Native source, collector and receipt joins

- One closed finite source under existing NativePeopleCustodyState: native
  world/source/batch/ordinal people; real two capsule aliases and original
  record identity; actual registration dock/accepted job; original
  version/digest. Identity survives reload/visit and does not depend on a new
  mission/party/index or version bump. Reaccept/reinstall cannot restock this
  incident.
- Native actor admission supplies physical body/owner/system/visit/source
  bindings. Only registered live occupied originals pass the native people
  collector. Real destruction preserves death; unloading/culling is not death or
  replacement. Captured/received actors cannot reproject as occupied originals.
- Extend the existing NativePeopleRuntime same-turn capture seal for the
  original source, preserving actual tools/aperture/motion/protection/capacity.
  No EMP flag, crew episode or captive/slave counter impersonation.
- Reuse real NativePeopleTransferReceipt and current native dock/care authority.
  G08 intermediate and final care give no incidental EMP/Station Aid payment;
  only the full mission terminal settles the authored reward.
- The record needs a genuine physical pickup receipt joining its original
  actor/identity, measured aperture/motion, slot, carrier and operation. Keep
  its one-tonne payload protected from sale/discard/substitution, with native
  pickup/transfer/loss provenance. Ordinary commodity fallback must refuse
  registered capsules/record when native proof is absent or malformed.
- Collection, care, consent/boarding and final people-plus-record reception
  publish through the existing candidate/writer. Failed publication preserves
  the same source identities and custody; retry cannot duplicate or backfill
  proof. Real physical death remains real even if a later mission write fails.
- Honest loss/refusal permits safe actual care and original-record return
  without a successful mission payment/clue. Existing occupied-berth escape
  restrictions remain; do not enable an unsafe escape to make a test pass.

## Proposed isolated ownership

Provisional **31 paths**, all one coherent G08 batch. Root reserves exact hunks;
G3 authors in isolation against the qualified integrated G05 base, G2 or the
designated independent agent reviews only after owner PASS, G1 alone
integrates/publishes. No canonical/live-CI edits. Remove unnecessary prospective
paths at preflight; any additional hook needs Root approval.

New implementation 5:

- `Sources/EliteCore/NativeOriginalRescueCapsules.swift`
- `Sources/EliteCore/NativeOriginalRescueJourney.swift`
- `Sources/EliteCore/NativeOriginalRescueJourneyBoard.swift`
- `Sources/EliteCore/NativeOriginalRescueRecord.swift`
- `Sources/EliteCore/NativeOriginalRescueJourneySave.swift`

Existing bounded source/consumer/save 19:

- `Sources/EliteCore/NativePeopleState.swift`
- `Sources/EliteCore/NativePeopleRuntime.swift`
- `Sources/EliteCore/NativePeopleStation.swift`
- `Sources/EliteCore/NativePeopleVersionedSave.swift`
- `Sources/EliteCore/ShipAccommodation.swift`
- `Sources/EliteCore/PassengerCustody.swift`
- `Sources/EliteCore/ScriptEncounters.swift`
- `Sources/EliteCore/NativeMissionActorAdmission.swift`
- `Sources/EliteCore/CargoScooping.swift`
- `Sources/EliteCore/FlightWorkGuidance.swift`
- `Sources/EliteCore/TargetColourClassification.swift`
- `Sources/EliteCore/ScriptPack.swift`
- `Sources/EliteCore/ScriptCommanderQuery.swift`
- `Sources/EliteCore/CommanderCargoValidation.swift`
- `Sources/EliteCore/ScriptPersistence.swift`
- `Sources/EliteCore/ScriptSaveJSONPreflight.swift`
- `Sources/EliteCore/ScriptBundledPacks.swift`
- `Sources/EliteCore/ScriptBaseClueCatalog.swift`
- `Tests/EliteCoreTests/BundledScriptPackTests.swift`

New qualification/content/notes 7:

- `Tests/EliteCoreTests/NativeOriginalRescueCapsuleTests.swift`
- `Tests/EliteCoreTests/NativeOriginalRescueJourneyTests.swift`
- `Tests/EliteCoreTests/NativeOriginalRescueRecordTests.swift`
- `Resources/ScriptPacks/l337-custody-rescue/manifest.toml`, relative to
  `Sources/EliteCore/`.
- `Resources/ScriptPacks/l337-custody-rescue/scripts/main.lua`, same
  Core-relative root.
- `docs/ISSUE-original-custody-rescue.md`
- `docs/PR-original-custody-rescue.md`

Specific adapter left to implementation preflight: connect record
capture/reserved-slot use to the existing authoritative post-motion
collector/publication seam in NativePeopleRuntime/CargoScooping. If that
genuinely requires another Game/runtime hunk or a current G04/G05 source-case
compatibility hunk, name it and obtain Root's reservation before editing; no
surrogate telemetry or new generic pod/history framework.

Propose **45 Normal/46 Alien**, subject to Root's current version reservation
after G05. Close genuine G08-only and G02/G04/G05/G08 composition independently;
lower envelopes reject new original-person/actor/record/boarding claims. No fake
G04/G05 claim, old-schema widening or migration project.

## Focused complete-journey acceptance

1. Atomic finite source/acceptance and truthful two-berth/one-slot quote;
   Back/stale/reinstall cannot initialise replacements.
2. Real original capsule/body capture, serial care and slot conservation.
   Empty/dead/unregistered/foreign/EMP-lookalike capsules refuse. Source
   death/unload/captured-actor restoration remains honest.
3. Same-reference care-to-cabin consent, refusal/withdrawal and two compatible
   real berths; no clone/duplicate admission or coerced transport. Preserve
   actual person census and original care history.
4. Actual unique record pickup and protected 1t custody;
   ordinary/replaced/foreign/destroyed/lost record cannot complete. Partial
   rescue/care/record stages pay no reward or clue.
5. Actual Celalen people-plus-record receiver pays 1020CR/clue once, frees exact
   custody/cabins and rejects wrong/partial/dead/stale/replayed reports.
6. Actual writer refusal/retry at collection/care/boarding/record/final
   reception conserves source, physical actor bindings, native
   people/slot/cabins/receipts/cash/clue without undoing real death. Current
   Normal/Alien cold reload and composed claims preserve all irreversible
   states.
7. Native pack CLI/digest, finite owner units PASS, then one independent
   complete-boundary review before G1 integration; no broad suite or
   pure-source/model completion claim.

## Root decisions and successor

Approve/fix: serial-care itinerary and reserved-slot policy; Cedamar/Celalen
route/L1/H0/1020CR; finite names/batch and native person transport intent;
supported physical templates/poses and one original record source; current save
pair and exact prospective ownership. The record/reservation caller adapter may
remain a named preflight question; it must not delay this draft handoff.

**G14 remains next queued successor**, with its distinct four-person
evacuation/source/receiver requirements. G08 care/consent patterns may help, but
two rescued people or a G08 receipt cannot substitute for four registered G14
survivors. No G14 work is assigned here.
