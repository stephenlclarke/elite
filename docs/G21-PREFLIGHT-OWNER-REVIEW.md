# G21 source preflight owner review

Source-only review, 16 October 2026, of exact `ea87bc57083926349a45f5a22694b25250705fac..5870151883289b1bda079ad53b5840e114cc904f`. Runtime/test candidate is `1353a6b07e70ac60aeef87c9ede0c933194890df`. Review and correction requests route through Orchestrator to Mission Coder 1; no Researcher builds, tests, native app execution or implementation-source edits occurred.

## Result

Preflight has two presentation findings and a separately approved pending raw-loader policy correction. It is not a final clean owner approval, canonical validation, main integration or historical mission-readiness claim. The proposed corrections change source and require final affected/native/media and canonical validation on the corrected immutable candidate under a coordinated lease.

1. **P2, introduced presentation issue:** `ScriptPledge.swift` lines218-220 display a500CR donation as5000decicredits and expose its full native receipt UUID in normal Gallery prose. The preview also exposes the internal provider key. The committed compact and wide completed-receipt images confirm this. Display the actual amount in ordinary CR, or tonnes Food, with human issuer/station and standing change. Retain exact internal units/UUID/provider identity in native records/query/developer evidence. Do not expose implementation terminology as necessary player instructions; preserve clearly labelled project estimates.
2. **P2, inherited visual acceptance defect:** the actual completed-receipt compact, scrolled and wide images contain overlapping Gallery header labels at y62. Existing Display.gallery paints both the docked/read-only status and active orange completion message in that band. This predates G21, but makes its delivered completion flow unreadable. A minimal additional owner-approved `MissionGallery.swift` header-only hook selects one text/ink: persistent trial context first, otherwise active message, otherwise ordinary docked/flight status. No broader Gallery/renderer change is authorized. Add an owned native assertion/capture showing readable completion and preserved trial context.

## Pending raw-loader placement correction

At this candidate, the unversioned raw-Commander branch of `GameRuntime.load(from:persistMigrations:)` decodes a valid new pledge state and then migrates/loads it without a format20 placement guard. Owner approves a guard immediately after actual raw Commander decode, before any migration/candidate load: `pledgeLedger` must be nil and every instance `pledgeReceiptID` must be nil. Otherwise throw `SaveError.invalidCommander`. Genuine legacy files with neither state retain their existing behaviour. The versioned pointer/chunk route remains the legitimate persistence path for new pledges.

Approve only that additional loader hunk and owned downgrade regressions, with no new writer/store/chunk or unrelated migration changes. Test legitimate completed pledge data encoded as raw JSON with persistMigrations true/false, marker-only and ledger-only raw cases, unchanged live state/input bytes on refusal, genuine old raw loads and valid format20 reloads. Direct trusted in-memory Game.load/Commander fixtures are not globally prohibited. This enforces format placement and retained internal consistency; it does not authenticate coordinated deletion/rewrite of every marker and ledger from an unauthenticated save.

## Source and evidence checked

Reviewed the typed ledger/issuer/receipt/marker invariants, original native admission/event linkage, exact all-or-nothing debit and automatic zero-payment completion, quote purity and resource checks, six fixed offers and cadence, protected-custody boundary, closed pack declarations, script command restrictions, backward-format guards, contract-page painted identity/actor dispatch, native menu/pointer/wheel wrapping, unaccepted trial review and existing ordinary-provider behaviour. The exact prior NativeView fixture paint/mouse modernization and four format assertions stay within approved scope. No additional introduced functional source issue was identified in these paths during preflight.

All779 `tested_source_inputs` hashes in the provisional validation document independently match this immutable Git revision. Its final delta from runtime/test candidate1353a6b consists only of documentation/provisional evidence and eight durable original PNGs. Patch size527537bytes and SHA256 `2a3783b228666bc0c9dc008bb58592236570f6827e4b06a4dc0d53aef14a984e` match the delivered patch. All eight committed PNG hashes match the evidence; the images were inspected individually without regeneration or alteration.

Reported passing subsets remain scoped to their actual checkpoints: core118 tests at245c77d, native21 atd5a0c3a and the affected native test rerun at1353a6b. The evidence correctly sets `canonical_make_ci_passed=false` and retains prior failures. No full gate, coverage, sanitizer or leak pass is inferred from these subsets, and the pending corrections invalidate affected source/media evidence until rerun. Formal PR review/fix/re-review and final-head checks remain required later.

## Ownership

Researcher leaves Mission Coder's reserved source regions untouched. Extra approved hooks are the precise raw legacy loader guard above and the single Gallery header band; all other new mission work remains exclusively through Orchestrator. The already approved pledgeReceiptID reverse link and actual-painted native fixture modernization remain in force. Separate finance/loan infrastructure, general equipment integration and remaining historical mission blockers are unchanged.

## Follow-up source review at8eda441

Reviewed exact `5870151883289b1bda079ad53b5840e114cc904f..8eda441b6def0e846c5240f0d6002871d02772aa`, source-only. Raw-loader9b5fcf1 puts the approved guard immediately after raw decode and before migration; genuine old/raw and trusted-memory/versioned positive paths remain. Swift amount formatting and human issuer/receipt text preserve exact native ledger/query facts. The Gallery header now emits one label, prioritizing trial context, active message and ordinary status. Those three original corrections are resolved in source; new presentation tests and corrected native captures remain unexecuted/pending.

**P1 introduced regression, source closure blocked:** the revised donation Lua generator calls `string.format` at line9. The actual protected host in `Sources/MissionScript/MissionScript.c` lines219-230 opens only base and math libraries; it never opens the string library. Accessing the absent string global on the first credit offer therefore prevents board generation, including all six offers and the donation trial. Prior-source passing tests cannot validate this unexecuted presentation change.

Fix only the authored Lua label expression with supported concatenation of its known integer amounts and a literal `.0 CR` (or `" CR"`). Do not expose additional sandbox libraries or change amounts, native arithmetic or host capabilities for display formatting. Re-run genuine generator/all-tier/native acceptance on the corrected immutable candidate under the assigned lease. Return its source diff for closure before final gates. No Researcher source edits or test/native execution occurred, and no final clean/canonical approval is granted by this follow-up.

## Corrected source closure at09bcf7b

Source-only review of exact `8eda441b6def0e846c5240f0d6002871d02772aa..09bcf7b60ee98b2e3355a46bce5621f3af0e21e9` closes the P1 regression. The authored generator now uses supported integer concatenation with literal `.0 CR`; no host/sandbox/library, native amount or seed changes occur. The genuine six-offer board fixture explicitly checks all six exact human credit/Food titles. Diff hygiene passes and no further source issue was identified.

All prior raw-loader, player-prose and single-header corrections are source-reviewed as resolved. This is source preflight closure only. Reported affected core7 methods/30 cases pass belongs to the corrected09 commit; Researcher ran no tests. Fresh native/corrected images, renderer media, final immutable refreeze, canonical CI and eventual owner integration/formal review remain pending. Stale prior captures or subset passes must not be promoted to final evidence.

## Corrected visual preflight closure at3a8d214

Owner source/visual preflight is closed for runtime/tests/Lua `09bcf7b60ee98b2e3355a46bce5621f3af0e21e9` and documentation/images head `3a8d2142412e56b9b28804a5eaef995f9cd0a3b1`. Their delta changes no Sources, Tests or authored pack inputs. All14 fresh original PNG hashes and10 byte-identical durable Git copies were independently checked; compact/wide originals were inspected, including an original-resolution check. Normal CR/Food and human issuer/standing prose, one completion header, trial priority and readable unavailable terms/actions satisfy the preflight findings.

The provisional787-input acceptance map is tied to09. At3a,779 entries still match and eight old durable image entries differ because corrected originals replaced prior captures; two new durable trial-header images were added. This expected post-acceptance media difference is not a runtime/test change, but must not be called all787 matching final inputs. The fresh images match their own original-renderer evidence. Retain both input scopes and prior failed/source images separately.

Media generation, a new immutable source/media checkpoint and complete input refreeze may now proceed to canonical make ci under Orchestrator's coordinated lease. The corrected scoped core7methods/30cases and native21 pass are preflight evidence, not a full gate. Final owner acceptance/integration still requires exact final source/media/evidence, uninterrupted successful canonical coverage/sanitizer/leak gates and frozen-hash verification. No Researcher build/test/native execution, main mutation, push, release or formal PR approval occurred.
