# fix(equipment): sort obligation keys and narrow mission validation inputs

Equipment obligation collection now sorts UUID keys by the exact original `uuidString` comparison, then resource keys by the same String ordering. Generic sorting no longer carries `(UUID, ScriptInstance)` or `(String, ScriptGearIssue)` elements. A fresh immutable member projection reads only actual ID, digest and gear issues from the current dictionary through a bounded non-inlined read boundary. The final inventory provenance join uses that same fresh narrow read instead of retaining a full mission instance.

`ScriptGearIssue.valid(for:)` borrows its original instance and delegates the unchanged predicate to ID/digest inputs. The collector calls this narrow predicate directly. There is no stored validation cache, external trusted projection or new schema; the complete original record-validity and obligation predicates remain. Every mission key must still equal its actual ID, every resource key its record resource, and the full native inventory/duplicate/provenance/item/returned/consumed/loan validation runs even when the collected list is empty. Legacy and mutation paths are unchanged apart from the borrowing predicate boundary.

## Correspondence and existing focused coverage

Static correspondence rebinds the new key lookups/projection fields to the original dictionary elements and rejoins the ID/digest predicate to its former instance inputs, recovering both entire source files byte for byte. Immutable current dictionary keys remain present during synchronous reads; a failed lookup still refuses with `obligationMismatch`. No guard, status branch or thrown error is removed. There are no Game, campaign, Director, Persistence, transaction, gameplay-scene, test, stack or concurrency edits.

Existing coverage is inventoried, not changed or rerun by this author:

- `ScriptEquipmentSeamTests`: exact removed-item mission/resource addresses; returned-record dictionary addresses; personal/issuer/resource/loan/kind substitutions; issued/released/absent nonloan histories; consumed/returned absence and active-loan presence; actual shared-round consumption and missing rights.
- `ScriptEquipmentReceiptTests`: actual refit/store displacement receipts; original return/release settlement; changed consumed/source/displacement refusal without state mutation.
- `ScriptEquipmentPersistenceTests.canonicalGearRecordsJoinAllChunksBeforeAdmissionAndCannotClaimContainer20`: full native inventory and retained issue join across saved chunks.
- `LegacyEquipmentMigrationTests`: old bag identities, held damage, loan/restoration and genuine nonloan absence; substituted/mixed representations refuse without allocation.
- `EquipmentIssueTransactionsTests.terminalAndReleasedObligationReciprocityCannotHideOrDuplicateSurvivors` and the existing script-equipment invalid-request, release/required-return and failed-publication rollback regressions retain the physical reciprocity checks.

Strict Swift formatting, paired Markdown lint, whitespace and source correspondence are source-only checks. No author compiler, test, native, profile, probing, disassembly or GUI jobs were run. G1 owns independent review, coherent composition and the necessary exact failure/affected validation; emitted ownership/stack reduction and retention success are not claimed from source alone. Already accepted campaign/context, EMP and graphics results remain retained, with unknown mission/native outcomes kept explicit.
