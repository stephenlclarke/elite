# G01 sealed dispatch: next bounded implementation handoff

Prepared 20 October 2026 for Root's dispatch approval after T04 integration. One
existing player-facing ledger family, not a new mission/framework. No
implementation or runtime work performed; M01 delivery remains first.

## Outcome, approved terms and readiness

**G01 / M05 / F35 / K05 / K09**, exact `l337.contract/sealed-dispatch`. The
ordinary station board offers a uniquely identified sealed one-tonne record.
Actual sender confirmation issues that item, actual destination contact receives
it, the existing native transaction pays once and the successful terminal grants
`sealed-dispatch-family-trace` once per commander. Failure/abandonment pays
nothing and cannot restore the lost original.

Authored authority: exact G01 template in
`original-missions/original-families.json` and its Markdown counterpart in this
design workspace. Required 1t,0berths/deposit/donation; quote `320 + 90*L +
80*H` CR; base deadline0 means **untimed**, not deadline-now. No perishable
allowance is authored.

Proposed ordinary production declaration for Root approval: H0, native reachable
original-world routes of 1–3 actual quoted legs, reward410/500/590CR
respectively. Expose only the three existing package rows1/3/5 from the native
six-draw courier generation; never expose its zero-tonne data rows or inherit
its old reward/duration schedule. Source is the actual offering main station and
receiver is the exact quoted destination/contact. No fixed artificial route,
hazard taxonomy or new monetary tuning.

Source inspected at canonical `fc214b89ea21c37f2f5138c764be92cbd62bffdc`,
containing integrated T04. G1 supplies the exact dispatch base after its current
M01 composition boundary is safe. Native producer prerequisites exist; the
remaining work is a closed untimed profile and its real production consumer.

## Existing authority and exact missing hooks

- `ScriptCourierDefinition/Terms/Custody` already contain a saved
  declaration/profile, native generation/row, unique item identity and
  issue/terminal proofs. No new ScriptInstance field is needed.
- `ScriptCourierGeneration` freezes actual reachable routes and six original
  draws. Select rows1/3/5 for G01 without rewriting or rerolling the generation.
  Existing rows retain their own original indices.
- `ScriptCourier.swift` already issues, delivers, abandons, handles actual
  package loss and creates native terminal/payment receipts using a non-Codable
  one-action admission. `confirmCourierDialogue` is the live receiver consumer.
- `ScriptContractCore` already builds the actual board, reserves/accepts the
  offer and publishes through the native candidate/writer. `ScriptContractState`
  supports duration0/deadline nil structurally, but its courier-specific branch
  currently imposes six rows and positive-duration headroom.
- `ScriptDirector.swift` already calls `awardScriptClue` after qualified command
  processing; delivered courier completion uses `dialogue.confirmed`. A frozen
  exact G01 production pin uses that normal existing terminal, with no
  acceptance-clue exception or Director change.

Actual profile hooks to change: courier definition's exact legacy-profile
restriction; board attach/validation's six-row positional mapping; courier
resource/job/custody headroom and mandatory-deadline assumptions; delivery's
forced deadline unwrap; medical/project-estimate/timed preview strings. Untimed
G01 must permit delivery with its exact nil deadline and explicitly refuse an
expiry terminal. Legacy timed providers keep all their existing deadlines,
inclusive boundary and six rows.

Retain issue/item/owner/digest/version/token/revision/station/sequence checks,
real capacity/range, unique accepted offer and native loss receipts. The three
displayed offers are separate consumable source obligations. A retry needs a
genuine new native offer/instance; neither Back, reload nor loss may recreate
the previous item. Do not add a second stock/receipt framework or claim a finite
global issuer inventory that the existing courier provider does not model.

## Proposed 15-path ownership

Root grants exact hunks before edits. **G3/MBA owns 13 paths; G1 owns 2 shared
presentation/discovery pins; G2 reviews the complete qualified boundary only
after owner PASS.** G1 composes the small shared hunks after T04/current M01
work; no parallel edit of its composition checkout.

G3/MBA paths, relative to the selected repository base:

1. NEW `Sources/EliteCore/OriginalSealedDispatch.swift`: closed exact G01
   declaration/profile/group/allowed rows/H0/reward/untimed predicates, called
   by the actual consumers below. No new saved model.
2. `Sources/EliteCore/ScriptCourierState.swift`: closed G01 definition/terms
   branch, package-only odd rows, authored formula and zero duration; custody
   validates exact nil deadline for G01 and refuses its expiry; legacy profile
   unchanged. Closed manifest contact/group validation remains mandatory.
3. `Sources/EliteCore/ScriptCourierGeneration.swift`: existing plan presentation
   selects declared package rows1/3/5 for G01; six-draw saved generator and
   legacy plan unchanged.
4. `Sources/EliteCore/ScriptCourier.swift`: G01 untimed original review
   text/resource/deadline/delivery guards; preserve non-Codable
   issue/reception/loss and payment authority. No force unwrap for G01's
   legitimate nil deadline.
5. `Sources/EliteCore/ScriptContractState.swift`: ONLY courier board/job
   validation permits the closed G01 row mapping and untimed headroom/group;
   every legacy courier invariant preserved. This is NOT MC1's
   ScriptMissionState.swift.
6. `Sources/EliteCore/ScriptContractCore.swift`: ONLY courier
   generation-to-offer attach/count hunk maps each selected G01 offer to its
   original row. Do not edit acceptance/publication/stack work or the completed
   G13 pledge branch.
7. NEW `Tests/EliteCoreTests/OriginalSealedDispatchNativeTests.swift`.
8. NEW `Tests/EliteCoreTests/OriginalSealedDispatchTests.swift`.
9. `Tests/EliteCoreTests/BundledScriptPackTests.swift`: directly affected
   default/dedup expectations only.
10. NEW `Resources/ScriptPacks/l337-sealed-dispatch/manifest.toml`, relative to
    `Sources/EliteCore/`.
11. NEW `Resources/ScriptPacks/l337-sealed-dispatch/scripts/main.lua`, same
    Core-relative root. Native plan/issue/deliver/abandon operations only; Lua
    cannot manufacture cargo, payment or clues.
12. NEW `docs/ISSUE-original-sealed-dispatch.md`.
13. NEW `docs/PR-original-sealed-dispatch.md`.

G1 sole shared hunks:

- **Path14:** `Sources/EliteCore/ScriptBundledPacks.swift`: exact production
  provider directory/default load/digest dedup branch only.
- **Path15:** `Sources/EliteCore/ScriptBaseClueCatalog.swift`: exact production
  definition/version/digest pin for genuine `dialogue.confirmed` completion
  after native pack validation. Preserve the G13-specific guard and every
  existing pin.

No Game, ScriptMissionState, ScriptDirector, save/preflight/envelope/schema,
equipment, OriginalContractOfferPolicy or new event hook is proposed. The
ordinary Original stable offer policy is reused; G13's hourly exception is
untouched. If Root's current M01 reservation includes either proposed
contract-file hunk, G1 must reserve/compose that exact hunk before authoring,
not let the worker edit the active owner. No required extra state/save path is
established by this source read; if one is demonstrated during implementation,
return to Root before expanding scope.

## Meaningful focused acceptance

1. Actual native loader validates the installed closed G01 declaration and
   immutable digest. Board shows exactly three one-tonne package offers with
   native rows1/3/5, routes and `320+90*L` CR, H0 and no deadline. Same source
   offer identity persists through Back/reopen/current load until a genuine
   native policy transition.
2. Real 1t capacity, actual origin/dock/fitting/fuel/reach and Original shared
   cap are required. No free cargo/credits on preview, Back, refusal, duplicate
   or stale acceptance. Accepted item is exactly the native issue for that
   original offer/instance.
3. Actual later destination contact delivers that same original item, pays its
   frozen route reward once and awards only G01's first-success clue. Wrong
   receiver/item/token/foreign profile/duplicate or acceptance-only flags cannot
   pay or award. Test actual writer refusal against full
   commander/stock/custody/payment/clue rollback and one valid retry.
4. Advancing the existing simulation/mission calendar past the old timed courier
   allowance never expires G01 or prevents its valid delivery. Its persisted job
   has duration0/deadline nil; do not use a huge deadline sentinel, new clock or
   fake timer. Existing timed profiles still expire/accept at their exact
   original boundaries.
5. Real abandonment/escape/fatal package loss pays zero, preserves the unique
   terminal and cannot restore/reuse the original consignment. A later
   legitimate job is a new native offer/instance. Repeat success retains the one
   G01 clue.
6. Normal/Alien current save/cold reload and existing W01/W02/W03/G13/T04
   composition keep valid native joins and reject
   profile/row/amount/deadline/item/receipt stripping or swaps. All fields use
   the existing courier representation; no new schema assumption.
7. Directly affected existing six-row courier plan/delivery/deadline tests
   remain correct. Owner ensures focused PASS plus native pack/digest
   validation, then one independent complete-boundary bugs/performance/style
   CLEAN review before integration. Do not turn this into broad regression work
   or bypass an M01 failure.

## Limits and approval

Root must approve the ordinary H0/three-package-row declaration and exact 15
paths before dispatch. Existing authored money/one-tonne/untimed terms are
preserved. This is not a global fleet activation, new campaign, financial/stock
framework, artwork pipeline or speculative physical mission. No source edits,
implementation, executable tests/builds or playable/M05/release completion are
claimed by this handoff. G1 remains sole ledger writer; other queue items stay
parked while this one is active.

## Approved ownership amendment — 20 October 2026

Root approved and assigned G01's exact existing 15-path scope, ordinary H0/one
tonne/untimed/package rows1,3,5 with six saved draws unchanged and reward
320+90L CR. The lower courier attach/count hunk is explicitly reserved and
disjoint from M01's old contractStation removal at the top of
ScriptContractCore.swift. No new clock, state, schema or scope is authorised.

Root has now reassigned ONLY the two central authoring paths from busy G1 to
idle G2: ScriptBundledPacks.swift's exact loader branch and
ScriptBaseClueCatalog.swift's exact production pin. G2 authors these in an
isolated checkout on qualified base `fc214b89ea21c37f2f5138c764be92cbd62bffdc`.
G3/MBA's 13 owned paths remain unchanged. This supersedes the earlier G1
central-author and G2 reviewer allocation; total paths remain 15.

The existing independent review agent reviews the complete 15-path boundary
after owner PASS. G2 must not review its own central changes. G1 remains sole
canonical integrator and publisher, with M01 delivery first. Combined
qualification uses G1's current integrated M01 base if available; authoring
isolation does not authorise changes to that composition checkout.

Root supplied the frozen production pack identity
`93289d5daf873d0cf878b37fa55178e4ab91cf6fa1947f379a54c3bc04267ae7`. This
identifies the frozen pack; it is not an assertion of native validation, owner
PASS, clean review or integration. Preserve actual qualification and delivery
evidence separately. No additional queue selection or source work is performed
by this amendment.
