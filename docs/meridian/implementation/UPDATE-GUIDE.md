# Keeping the finished-game bundle in sync

The canonical mission and gameplay inputs are below [missions/](../missions/README.md). This guide defines document maintenance, not implementation ownership or another packet queue.

## Change together

For a campaign change, update its canonical JSON, affected physical/recovery profile and its illustrated C01-C39 reading view. Update the same section in the full oracle. Preserve stable mission, stage, target, branch and clue identities unless an explicit design change requires a recorded migration. Stage order and actual receiving world are part of the specification, not just narrative captions.

For a family/service/lesson change, update its template in `original-families.json` or `wayfarer-services.json`, its source-specific recovery profile, contract/tutorial reading view and full oracle. For a clue/finale change, reconcile the exact source/clue register in `unwritten-route.json`, recovery policy, finale reading view and full oracle. Keep the current required set at64 sources; additional independent epilogue evidence is not its own prerequisite.

For a ship/equipment change, update the canonical numerical definition, relevant gameplay tables, ship appendix and mission capacity/compatibility consequences. Keep ship reference diagrams associated with their exact original geometry and label their calibration status. Do not substitute old main fleet images or claim an illustration is a renderer capture.

The complete oracle is the reading assembly of the current rules; the shorter Markdown files retain its sections with relative links rebased for their directories. Do not append new gameplay after its final ship-reference section. The standalone physical operations/recovery specification must agree with its embedded section in the oracle and gameplay view.

## Static document acceptance

Check JSON/TOML parse, all local links and Markdown anchors,39 campaign graphs/368 stages,78 explicit branch variants,64 distinct source/clue joins, all31 physical profiles and their real target joins, and all64 guaranteed continuity paths. Account for the320 renewed/remedial plus320 continuity-inquiry alternative objective rows separately from the450 original stage rows. Check all declared cargo effects, including C01's1.008-tonne peak and actual final recorder archive, and Small Lights' two installed plus two separate reserve kits. Preserve existing image bytes and qualified provenance unless the artwork itself changes.

Refresh the per-definition SHA256 source index, per-campaign graph/custody checks, objective inventory, coverage and document-validation receipt. Preserve the frozen runtime-baseline attribution; new design does not increase native coverage. Native implementation acceptance later needs actual UI, flight, loss, functional-test, custody and save/reward-replay evidence through the real runtime, with project gates when authorised.

## Ledger snapshot

Capture the published main-ledger document branch at its exact commit using the immutable Git object. Copy its bytes unchanged to `COMPLETION-LEDGER.snapshot.md`; record commit, capture time, branch, immutable source URL and matching source/copy SHA256 in `LEDGER-SNAPSHOT.json`. The implementation guide must call it a read-only snapshot and link the live ledger. Never edit the snapshot to record new assignments or progress. Historical relative links and formatting in that exact-byte copy are intentionally preserved; they are not new bundle navigation.

## Provenance and precedence

Original authoring and copied historical runtime contracts are frozen supporting sources. Keep their source hashes and scopes in the consolidated-source manifest. Their earlier field values or bindings do not override later explicit final-game decisions. Mark estimates and unqualified native work plainly. The coherence review records design resolution; the mechanics audit records actual implementation evidence at its stated baseline. Neither substitutes for the live ledger or qualifies a release.
