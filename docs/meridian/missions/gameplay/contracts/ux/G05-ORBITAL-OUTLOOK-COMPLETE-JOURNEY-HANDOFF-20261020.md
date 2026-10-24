# G05: complete three-view passenger journey

Queued recommendation for Root approval, 20 October 2026. No implementation or
execution. G04 is owner-qualified and entering G1 integration; author G05 only
against its actual qualified integrated source. M01 remains first.

## Existing authority and approved-design limits

**G05 / M09 / F33 / F35 / K08 / K11**, `l337.contract/orbital-outlook`.
Authoritative G05 template: `original-missions/original-families.json` and .md
in this design workspace; ENGINE-CONTRACT.md requires actual targeted scans,
exact identities, distinct targets, normal controls and real reception.

Authored: two consenting named passengers, two real berths, zero cargo/deposit,
three ordered orbital views, same living passengers returned, no mission
deadline; reward `650+110L+80H` CR; clue `orbital-outlook-family-trace` once.
**G05 scanSeconds is 0: a dwell duration is not authored.** No separate approved
G05 interaction handoff was found in the checked handoff/design directories. The
retained MBA09 proposal concerns G10's 12-second survey and was PARKED, not
implemented or approved as G05.

Reuse G04's genuine station-person identity, native reply/boarding records,
compatible fitted cabins and native receiving receipts. Qualified G04 source is
retained through `/tmp/elite-g3-G04-active` and OWNER-QUALIFICATION.json. Its
identity validator/source/policy are hardcoded to G04's batch and one-way
journey: do not reuse its already-allocated people or pretend it already
supports a tour.

## Recommended ordinary variant: Root decisions

- New finite G05 batch of two genuine named station people: **Avenor7 → Renas185
  → Avenor7**, L2/H0, **870CR** only after actual return reception. Their native
  travel intent and replies consent to the entire ordered three-view itinerary
  and return, not merely the outward destination. Freeze original names/batch
  before tests.
- Three distinct, stationary, noncombat viewing markers admitted by the existing
  supported native mission-actor machinery at Renas. Freeze exact supported
  template, collision-clear poses and stable mission actor identities in the
  production declaration before tests; use no new hull/rendering system or
  fictitious off-screen point.
- Recommend automatic observation when the existing fitted targeting computer
  locks the NEXT marker in the forward view after boarding. Existing target
  selection and weapon controls remain unchanged; no hidden scan key, new
  weapon/tool or Return-to-scan behavior.
- Recommend **12 qualified native-flight seconds per view**, surface range
  250–1500 native flight units and 2-degree boresight, with that exact marker
  the nearest real GameplayRaycast hit. These are NEW G05 defaults for Root
  approval, not old approved requirements or verified metres. Rationale: a
  readable deliberate view, safe separation and existing native
  targeting/raycast machinery.
- Pause freezes observation. Target/range/LOS/visit/equipment discontinuity
  resets only the current unfinished view. Cold load preserves completed views
  but requires a fresh unfinished scan; advertise this policy.
  Out-of-order/repeated views never substitute for another.

## Actual producer, receipt and receiving joins

Existing native facts: physicalTime/player/visit/pose, live registered actor
geometry, real raycast and target selection. Target telemetry does not itself
produce a completed scan. The missing operation is the closed G05 post-motion
observation producer.

Current GameRuntime.advance calls prepareAdvance, game.tick and station-entry
commit, then finishAdvance. G1 reserves an optional G05 pre-motion sample and
ONE post-motion scan commit in that actual phase, using measured start/end
physical facts and the existing publisher. The existing pre-motion work planner
or renderer cannot advance scans. Capture only bounded native facts, never a
whole Game snapshot in the frame context.

Only contiguous, positive native intervals up to 0.1s may accrue, with the same
owner, journey/boarding, two live native passengers/berths, carrier/equipment,
player/visit, next marker and qualified geometry. Oversized/missing intervals
cannot be backfilled or converted from a supplied elapsed-time value. Partial
dwell is transient; only up to three completed native readings persist. No
per-frame save or separate clock.

Each completed receipt binds journey/source/boarding, both passenger references,
carrier/berths, target ordinal and stable actor identity/system, observed
visit/native interval and operation/revision. Native code seals it;
Lua/read/render/arrival flags cannot create it. Publish the exact reading and
ordered progress atomically. Writer refusal grants no saved reading or time
credit; any retry uses only the same genuinely measured pending receipt, never
unobserved elapsed time or physics rollback.

At Avenor, actual native reception must name exactly G05's two living people,
verify all three ordered receipts and real return dock after the viewing visit,
release those berths, then commit 870CR and its clue once. Keep G04/G05 care
selection separate: neither party may be offloaded or settled through the
other's contact/receipt. Loss remains loss and cannot repopulate the source.

## Proposed 25 paths and ownership

Root reserves exact hunks before edits. MBA/G3 owns 19 isolated paths; G1 owns 6
protected frame/save/discovery hunks or delegates their isolated authoring. G1
alone integrates. No canonical mutation during G04 integration/live CI.

G3 new closed implementation 4:

- `Sources/EliteCore/NativeOrbitalOutlookJourney.swift`
- `Sources/EliteCore/NativeOrbitalOutlookScan.swift`
- `Sources/EliteCore/NativeOrbitalOutlookJourneyBoard.swift`
- `Sources/EliteCore/NativeOrbitalOutlookJourneySave.swift`

G3 existing native/UI 7, G05-only joins preserving G04:

- `Sources/EliteCore/NativePeopleState.swift`: one closed G05 source/scan leaf
  and actual identity/custody joins; no cloned roster.
- `Sources/EliteCore/NativePeopleStation.swift`: People UI and exact-party
  native receiving/loss dispatch.
- `Sources/EliteCore/NativeStationPassengerJourney.swift`: only bounded
  identity/reusable native record support for the explicit G05 batch; preserve
  G04 consent policy.
- `Sources/EliteCore/NativeStationPassengerJourneyBoard.swift`: preserve exact
  G04 receiving membership and genuine loss handling when both families exist.
- `Sources/EliteCore/NativeStationPassengerJourneySave.swift`: G04-specific
  validation remains independently closed when genuine G05 people are present.
- `Sources/EliteCore/ScriptCommanderQuery.swift`: actual people/mission count,
  next target and progress facts.
- `Sources/EliteCore/ScriptPack.swift`: closed G05 declaration, itinerary, scan
  conditions and existing actor declarations only.

G3 UI/content/tests/notes 8:

- `Sources/EliteCore/TargetPanel.swift`: actual next view, 0/3–3/3 and measured
  scan progress/reason; display never advances it.
- NEW `Tests/EliteCoreTests/NativeOrbitalOutlookScanTests.swift`
- NEW `Tests/EliteCoreTests/NativeOrbitalOutlookJourneyTests.swift`
- `Tests/EliteCoreTests/BundledScriptPackTests.swift`: affected defaults only.
- NEW `Resources/ScriptPacks/l337-orbital-outlook/manifest.toml`, relative to
  `Sources/EliteCore/`.
- NEW `Resources/ScriptPacks/l337-orbital-outlook/scripts/main.lua`, same
  Core-relative root.
- NEW `docs/ISSUE-original-orbital-outlook.md`
- NEW `docs/PR-original-orbital-outlook.md`

G1 protected 6:

- `Sources/EliteCore/Game.swift`: bounded optional native frame
  sample/observer/transient lifecycle only; no physics, combat or clock
  refactor.
- `Sources/EliteCore/NativePeopleVersionedSave.swift`
- `Sources/EliteCore/ScriptPersistence.swift`
- `Sources/EliteCore/ScriptSaveJSONPreflight.swift`
- `Sources/EliteCore/ScriptBundledPacks.swift`: exact default provider/dedup.
- `Sources/EliteCore/ScriptBaseClueCatalog.swift`: exact native-validated
  production pin.

Propose NEW 43 Normal/ 44 Alien for the new G05 claims, **subject to Root
reservation**. G05-only and G02/G04/G05 composition independently validate every
genuine present feature; lower versions reject G05. Do not silently widen 41/42
or require a fake G04/G02 claim. Exact current envelope mapping is G1's
decision. No new framework or generic scan SDK; any demonstrated extra path
returns to Root before edits.

## Bounded complete-journey qualification

1. Real finite G05 people, full-itinerary native accept/refuse/withdraw replies
   and atomic two-berth boarding. Back/stale/refused/one-berth states change
   nothing; G04 people are not replacements.
2. Actual admitted marker and measured qualified frame sequence produces exactly
   one reading. Wrong/out-of-order/duplicate/cull/destroyed target, occlusion,
   wrong aim/range/tool state, pause/render/read, stale visit/epoch and
   oversized intervals cannot invent progress.
3. Completed views persist across interruption/load; unfinished continuity obeys
   the advertised reset rule. Third view alone never pays.
4. Complete normal UI/native flight journey: board, actual Renas visit, all
   three views in order, actual Avenor return, exact-party reception, 870CR and
   one G05 clue. Include wrong/early/replayed reception, actual passenger loss
   and concurrent G04 party isolation.
5. Actual scan/boarding/reception writer refusal conserves
   people/cabins/receipts/cash/clue and real post-motion physics; honest retry
   cannot backfill time. G05-only and composed Normal/Alien cold joins reject
   forged/stripped/cross-family claims.
6. Native pack CLI/digest plus focused owner PASS, then ONE independent
   complete-boundary review. Reuse relevant G04 evidence; no broad suite,
   another scan prerequisite-only feature or unrelated M01 work.

G08 and G14 remain queued behind their own real non-EMP capsule/evacuation
sources. This handoff proposes one complete G05 journey for Root's
scope/defaults/save decision; it claims no authored implementation or runtime
qualification.
