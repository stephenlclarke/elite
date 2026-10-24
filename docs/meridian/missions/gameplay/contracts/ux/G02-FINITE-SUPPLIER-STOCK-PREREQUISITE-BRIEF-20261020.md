# G02 finite supplier stock: queued prerequisite brief

Accepted by Root on 20 October 2026 as queued prerequisite design, **not an
implementation assignment**. G07 remains the sole active MBA implementation
until its freeze/review handoff. M01 delivery remains first. This file preserves
the accepted brief outside canonical/live CI; it authorises no source edits,
execution or queue expansion.

## Identity and source

**G02 / M05 / F35 / K05 / K09**, exact `l337.contract/consented-freight`. Source
read: canonical `ff52dae618c16db1652eb75f33ffe33b135dce11`. Authored authority:
exact G02 template in `original-missions/original-families.json` and its
Markdown counterpart in this design workspace.

Authored terms: eight tonnes of utility parts; zero berths/deposit/donation;
untimed base; reward `620 + 110*L + 80*H` CR. Exact first-success clue:
`consented-freight-family-trace`.

`ScriptFreightIssueAdmission` currently derives issued IDs from the native
instance; it does not debit supplier inventory. `ScriptOwnedCargoState` already
carries issued/held/transferred/lost units. `ScriptFreightCollections` already
binds the exact native dock, current named receiving choice and transferred unit
IDs. Reuse these authorities.

## Meaningful player batch

An installed G02 supplier declaration defines one finite original batch at a
real main station. Actual source Confirm issues exactly eight **pre-existing
stock-unit IDs** into protected hold. The matching receiver's fresh receiving
consent uses the existing native contact/choice/collection receipt for those
same IDs. Seven delivered tonnes remain active and unpaid; the eighth qualifying
original unit commits existing settlement and the G02 clue. No Lua consent
boolean or ordinary commodity substitution.

## Smallest new authority

One closed G02 supplier-stock leaf contains owner/native source/batch/original
definition/version/digest, finite unit IDs and once-only allocations to native
freight instances. Source identity excludes digest, so reinstall/update cannot
recreate that same batch. Remaining inventory derives from initial units minus
allocations. Player/receiver/lost location derives from existing
held/transfers/terminal records. No second receiver ledger, per-frame mutable
counter, restock, clock or new loss hook.

## Required actual issue hook

Native freight issue must commit stock allocation and `ScriptOwnedCargoState`
together in the same candidate. Have the existing non-Codable issue admission
return a G02 stock delta; its ScriptDirector freight-issue caller installs the
delta with the issued instance **before existing validation/publication**.

The current signature is `issue(into:inoutScriptInstance,game:Game)`: its
immutable Game argument cannot safely debit stock by itself. A new leaf/helper
alone does not complete this producer. The implementation must compose the real
caller and persistence joins before qualification.

## Prospective 17-path ownership

Root must reserve exact paths/hunks and agree source/save contracts before
implementation. This ownership proposal preserves live CI and main-owned files.
G1 remains sole canonical integrator; Root may delegate central authoring in a
separate isolate.

MBA/G3 isolated 11:

1. NEW `Sources/EliteCore/OriginalConsentedFreightSupply.swift`: closed supplier
   declaration and finite stock/allocation leaf.
2. NEW `Sources/EliteCore/OriginalConsentedFreightSupplyCommands.swift`: native
   source, allocation and receiver joins.
3. NEW `Sources/EliteCore/OriginalConsentedFreightSupplySave.swift`: strict
   fields and closure predicate, consumed by the central publication/read
   integration.
4. `Sources/EliteCore/ScriptFreightGeneration.swift`: exact G02
   eight-tonne/zero-deposit/authored-formula profile and immutable supplier
   declaration.
5. `Sources/EliteCore/ScriptPack.swift`: closed freight.supply declaration
   whitelist.
6. `Sources/EliteCore/ScriptFreight.swift`: actual source admission, original
   stock IDs and returned stock delta.
7. `Sources/EliteCore/ScriptFreightCollections.swift`: G02 receiver-consent
   predicate using existing native receipts.
8. NEW native supplier unit file under `Tests/EliteCoreTests/`; proposed name
   `OriginalConsentedFreightSupplyNativeTests.swift`.
9. NEW lifecycle unit file under `Tests/EliteCoreTests/`; proposed name
   `OriginalConsentedFreightSupplyLifecycleTests.swift`.
10. NEW `docs/ISSUE-original-consented-freight-supply.md`.
11. NEW `docs/PR-original-consented-freight-supply.md`.

Protected central 6, separately reserved and composed by Root/G1:

- **Path12:** `Sources/EliteCore/ScriptMissionState.swift`: one optional engine
  stock leaf and its validator join.
- **Path13:** `Sources/EliteCore/ScriptDirector.swift`: only the existing
  freight-issue call and returned-delta/issued-instance join.
- **Path14:** `Sources/EliteCore/ScriptOwnedCargoState.swift`: only G02 issued
  IDs join the supplier allocation; existing profiles keep deterministic IDs and
  all existing checks.
- **Path15:** `Sources/EliteCore/ScriptPersistence.swift`: exact
  stock-field/publication/read integration.
- **Path16:** `Sources/EliteCore/ScriptSaveJSONPreflight.swift`: closed feature
  placement validation.
- **Path17:** `Sources/EliteCore/ScriptFreightVersionedSave.swift`: exact G02
  plan/declaration whitelist.

No Game, equipment or physics hook is proposed. No canonical/live-CI mutation is
authorised. Default pack/UI/media delivery is later; these 17 paths are one
coherent native prerequisite boundary, not 17 independently complete features.

## Protected persistence boundary

Real finite stock cannot persist using the producer-only files. G1 must approve
the exact current-format envelope/version decision and closure checks before
qualification. Do not assume 37/38 reuse, guess a new version or redesign
generic schemas.

Every allocated source ID must join exactly one retained G02
custody/transfer/loss path. Reject stripped/orphan/cross-batch/double-allocated
fields. Broad central restructuring is outside this scope. The MBA may
eventually author its isolated source/consumer subset against agreed signatures,
but that subset is **not a standalone completed delivery**. Central 6 must
compose and actual owner units pass before integration readiness.

## Focused unit acceptance

- Authentic source pickup: seven tonnes free refuses; eight succeeds. Source
  inventory decreases by eight, and issued IDs equal the original supplier IDs.
- Stale/double/reinstall/foreign allocation refuses without source or hold
  changes.
- Actual receiver token/dock/contact consent consumes those same units. Partial
  seven pays nothing; final eighth commits exact reward and once-only clue.
- Actual escape/abandonment/loss never replenishes source stock.
- Source/receiver writer refusal rolls back full source/hold/receipts/cash/clue
  state atomically.
- Current cold reload preserves exhausted/partial/lost joins. Directly affected
  legacy timed/bonded profiles retain their original IDs and behavior.
- Use one small finite batch, for example 16t/two issues **only if Root approves
  that quantity**, and exhaust it. No stress harness, broad audit or invented
  stock fixture standing in for the real consumer.

## Root decisions required before dispatch

Freeze the actual source batch quantity and commodity mapping;
Machinery-as-utility-parts is proposed only. Freeze supplier/receiving contact
and port, routeL and declaredH; ordinaryH0 is proposed only. These exact
count/location choices are not supplied by the authored template. Agree the
protected current-save integration decision and exact caller contract.

This is the smallest coherent specific producer prerequisite accepted for the
queue. It does not claim source implementation, compiled code, native producer
qualification, passing tests, a playable G02 family or release readiness. No
additional research/design expansion follows from acceptance of this brief.

## Compact ledger entry for G1's next normal update

**G02/M05-F35-K05-K09 finite supply prerequisite — not started.** Root accepted
queued design only; no author/implementation reservation. Prospective coherent
17 paths: MBA 11 plus protected central 6. Requires explicit finite source
batch/commodity/contact/route and current-save/caller decisions. Reuse existing
freight custody, native receiving choices and settlement; preserve original
supplier IDs through allocation, delivery or loss. Next handoff: Root approves
exact scope/content/central ownership after G07 closes, then owner-focused PASS
and one independent review. M01 first; G07 remains sole active MBA item. No
live-CI/canonical ledger change by this design thread.
