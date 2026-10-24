# W03 / MBA13 approved implementation handoff

Approved by Root on 20 October 2026. This records one existing ledger service,
not a new work item or implementation delivery. M01 retains first resource
priority; G11 isolation work is parked.

## Identity and source

- Ledger: M09 / F33 / K08 / K09; service inventory also contributes to F35.
- Exact service: `l337.wayfarer-service/seed-transfer`, Seed-bank transfer.
- Exact first-success clue: `exchange-service-seed-transfer`; receipt
  `l337.unwritten-route/clue/exchange-service-seed-transfer`.
- Approved design authority: `original-missions/wayfarer-services.json`, its
  `seed-transfer` template; `original-missions/wayfarer-services.md` Seed-bank
  transfer section; `original-missions/ENGINE-CONTRACT.md` service contract
  paragraphs at lines80–82. These paths are relative to the parent of this
  handoff's `gameplay-design` directory.
- Bounded source inspection:
  `~/.codex/worktrees/canonical-mission-composition/elite`, observed HEAD
  `162bb83ea96f49278b8095b72e621ed5af79e749`. W02 composition was entering that
  tree. G1 selects the actual integrated W02 base for authors; the observed HEAD
  is not a claim that W02 was already committed there.
- Root/session: `01a134a1-be40-77d0-9e11-64a775729232`. G1 owns current ledger,
  source composition and integration. G2 owns native6; G3/MBA owns UI9. Each
  owner supplies and ensures its focused unit tests pass.

## Approved ordinary production terms

- **Source:** Celalen, galaxy 0/system 241, actual main orbital station
- **Objective and receiver:** Cedamar, galaxy 0/system 85, actual main orbital
  station
- **Route:** `[241, 85]`; one quoted leg, L=1
- **Source stock:** Six finite, uniquely identified three-tonne lots; no
  replenishment
- **Capacity:** Three actual free cargo tonnes; zero passenger berths
- **Hazard:** H=0; ordinary variant
- **Reward:** 605CR / 6050 native: `510 + 95*L + 110*H` CR
- **Seed viability:** Explicitly advertised 2700 armed-flight seconds after
  actual pickup
- **Timing qualification:** Authored allowance, not a measured route-travel
  bound; pause freezes it and current-format load preserves the original
  remainder
- **Custodians:** Two distinct named source/receiving seed-bank custody
  contacts, bound to the actual native release and acceptance
- **Completion:** Same original lot reaches its named receiving custodian;
  actual objective verification and separate final reception Confirm

The contact display names and stable IDs must be explicit immutable content
values, distinct at source and receiver, and bound to the native
custody/definition/digest. This approval does not supply particular spellings.
They do not require a living passenger party and must not claim seed-ark or
survivor reception. No Lua consent flag supplies release or acceptance
authority.

## Existing producers and actual consumer

`WayfarerColdChainCommands.swift` already provides native finite source
initialisation, quote/pickup, objective verification, receiving handoff,
absolute `.flight` one-shot expiry, loss, payment and clue publication.
`WayfarerColdChainContact` joins the actual `NativeMainStationDockReceipt`,
owner, sequence and causal context. The service consumes these existing
operations through the actual station board; its Lua is metadata and the
existing protected expiry handler.

`WayfarerColdChainBoard.swift` already routes fresh board review/Confirm into
the native candidate transaction. `CommanderCargoValidation.swift` counts
payload amounts in tonnes. Existing Game escape/fatal-loss hooks call the same
custody loss functions. Existing stock/custody leaves and the native save writer
are reused. No new clock, generic custody/stock/receipt framework or parallel
save writer is authorised.

The actual gap is a closed second profile: current W01 definitions, identity
gates, one-tonne checks, formula, payload validation and medical labels are
W01-specific. Extend those exact consumers for W03; a pack alone cannot make
this service executable.

W01's absent profile defaults **only for the exact W01 definition**. W03
requires an explicit closed profile and source/receiver custodian joins.
Unknown, missing, stripped or cross-profile fields cannot fall back to W01.
Preserve original W01 behavior and its identity/digest/receipt guards. Namespace
W03's stock identity so a reused batch label cannot alias W01 stock. Three
tonnes describe one protected consignment, not three independently claimable
rewards.

Use the existing 37/38 current save envelope and existing full-state fallback.
Extend strict nested definition validation for the approved fields; do not
weaken it. If actual implementation proves another persistence/version path
necessary, stop for Root's exact reservation before editing it. No migration
work or new format is approved by this handoff.

## Exact approved 15-path ownership

Paths below are relative to G1's selected repository base. The two new resource
paths beginning with `Resources/` are relative to `Sources/EliteCore/`. Shared
files are reserved only for the named W03 hunks. G1 composes the two subsets;
authors must not edit one another's hunks.

- **G2 native1:** `Sources/EliteCore/WayfarerColdChainCommands.swift`. Closed
  W03 profile/custodian declaration, per-profile identity/formula/payload, 3t
  capacity, stock namespace and existing issue/expiry/reception/loss dispatch
- **G2 native2:** `Sources/EliteCore/WayfarerColdChainSave.swift`. Exact
  declaration/state/custodian/profile joins, strict nested keys and
  declared-tonnage payload validation; reject stripped/orphan/swapped claims
- **G2 native3:** `Sources/EliteCore/ScriptPack.swift`. Only the existing
  `coldChain` strict declaration whitelist and closed W03 fields
- **G2 native4:** `Sources/EliteCore/ScriptCommands.swift`. Existing
  native-command protection covers exact W03 and orphan state; generic
  payload/credits/finish/timer bypass remains refused
- **G2 native5:** `Sources/EliteCore/OriginalServiceReservationPolicy.swift`.
  Match the existing custody leaf to its closed definition; retain one aggregate
  three-service/Original-contract cap
- **G2 native6:** NEW
  `Tests/EliteCoreTests/WayfarerSeedTransferNativeTests.swift`. Focused native
  profile/custody/capacity/expiry/save/protection units owned by G2
- **G3 UI1:** `Sources/EliteCore/WayfarerColdChainBoard.swift`. Actual3t review,
  seed-bank contact/consent/quote/budget labels, correct state/clue lookup and
  unchanged native Confirm publication
- **G3 UI2:** `Sources/EliteCore/ScriptBundledPacks.swift`. Exact seed-transfer
  provider loader and same-digest deduplication
- **G3 UI3:** `Sources/EliteCore/ScriptBaseClueCatalog.swift`. Exact production
  execution pin after native validation of the frozen pack digest; existing
  64-source count unchanged
- **G3 UI4:** NEW `Resources/ScriptPacks/l337-seed-transfer/manifest.toml`.
  Approved immutable production terms, distinct contacts and service identity
- **G3 UI5:** NEW `Resources/ScriptPacks/l337-seed-transfer/scripts/main.lua`.
  Metadata and existing protected expiry handler only; no
  stock/consent/payment/clue authority
- **G3 UI6:** NEW `Tests/EliteCoreTests/OriginalSeedTransferTests.swift`. Actual
  production board/pickup/dock/objective/reception/payment/clue and
  rollback/reload units owned by G3
- **G3 UI7:** `Tests/EliteCoreTests/BundledScriptPackTests.swift`. Only directly
  affected default-provider/digest-dedup assertions
- **G3 UI8:** NEW `docs/ISSUE-original-seed-transfer.md`. Concrete scope,
  dependencies and truthful owner qualification status
- **G3 UI9:** NEW `docs/PR-original-seed-transfer.md`. Final implementation,
  frozen source/digest and meaningful focused evidence

The separate native test filename above names the added fifteenth path; Root/G1
should reconcile any already-dispatched spelling before creation. The ownership
split and one native test path are approved; it is not permission to add a
sixteenth path.

No `Game.swift`, Director, `FlightWorkTools.swift`, native salvage,
`ScriptMissionState.swift`, `ScriptPersistence.swift`, new schema, artwork
pipeline, broad audit or unrelated M02/M19 rename is in this scope. Additional
paths require Root approval. Reuse the existing loss hooks; do not import
unqualified MC1 changes.

## Focused owner acceptance

1. Production board Back/reopen/current reload preserves the same original lot
   and immutable quote. No acceptance/payment/cargo mutation on Back.
2. Two free tonnes refuses pickup; three free tonnes admits exactly one original
   3t consignment. Ordinary cargo and the shared W01/W02/W03/Original-contract
   cap still apply; no sale, pledge or second pickup bypass.
3. Real later Cedamar dock/objective verification followed by separate receiving
   confirmation transfers that exact viable lot, pays 605CR and awards only
   W03's first-success clue once.
   Wrong/foreign/W01-swapped/stale/duplicate/consent-mismatched confirmations
   cannot pay.
4. Actual pickup and reception writer failure preserve full commander, stock,
   custody, time, payment and clue state. Native action publication remains
   atomic.
5. Pause and current-format cold load preserve the original absolute integrity
   budget. Actual expiry or escape/fatal loss pays nothing; retries consume
   another finite original lot; all six exhausted lots never replenish.
6. Normal/Alien save composition with W01/W02 retains legitimate identity and
   rejects stripped profile/custodian/quantity fields or cross-profile
   receipt/source corruption. Preserve directly affected W01/W02 behavior with
   focused regression units.
7. Validate the actual frozen production pack with the native loader/CLI before
   pinning its digest. Each author ensures its focused units PASS; then obtain
   one completed independent bugs/performance/style review of the combined
   qualified boundary before G1 integration.

Broad suites stay at their existing batched/final checkpoints. Owner results,
combined source qualification, actual integration, playable application and
release remain separate recorded events. This handoff performs no
implementation, compiler/test run, artwork generation or gameplay/release
qualification. G1 is the sole current ledger writer; the designer remains on
standby for concrete specification questions.

## Approved save-envelope amendment — 20 October 2026

Root approved this concrete source-confirmed scope resolution after receiving
the original handoff. It supersedes the earlier fifteen-path ceiling and
exclusion of ScriptPersistence.swift. The current total is **17 paths: G2
native6, G3 UI9, G1 central2**. G2/G3's original owned paths remain unchanged;
only G1 may edit these two additional central files:

- `Sources/EliteCore/ScriptPersistence.swift`: select and read the existing37/38
  envelope for genuine W02 **or W03** claims, including a W03-only commander.
  Validate each present feature independently and require at least one genuine
  W02 or W03 claim; W03 does not need a fabricated W02 claim.
- `Sources/EliteCore/ScriptSaveJSONPreflight.swift`: enforce the corresponding
  closed feature/envelope boundary. Older35/36 must refuse W03 claims;37/38 must
  not admit a stripped or forged feature declaration or bypass either feature's
  own validity.

The source-confirmed problem is that the previous writer would select35/36 for
W03-only state, while the existing37/38 reader required W02. Merely adding W03
to the nested W01 definition whitelist would leave that actual publication/read
path inconsistent. Root therefore reserved these exact central hunks to G1; this
is an approved prerequisite resolution, not permission for the native/UI authors
to expand their files or weaken validation.

Reuse existing37/38; no new save version, migration framework or Game hook is
authorised. Qualification must cover the real W03-only Normal/Alien envelope and
W01/W02/W03 composition, including absent/stripped/foreign feature negatives,
within the already-owned focused tests. G1 composes the two central hunks with
both author subsets and records actual qualification/integration separately.
G1/G2/G3 were already informed by Root; the designer adds no implementation or
ledger work and remains on standby.
