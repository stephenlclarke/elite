# Native station budget fixtures follow current source admission

## Motivation and bounded correction

CI955 records two stale count failures: NativeStationStateTests line 140 expected construction of 373 records to fail, while line 259 received typeMismatch at records[0] instead of the oversized-array error. NativeStationLedger.recordLimit now follows the actual original station source bindings. Its initializer and decoder still enforce that limit; 373 is no longer necessarily excessive. The decoder checks known array length before decoding any element.

Require a positive actual recordLimit within maximumSourceRecords, whose declared ceiling is 8*(256+1). Use limit+1 for excess records. Construct structurally valid unique records using the two original source-class slots per ordinary system, so rejection cannot be attributed to invalid identities or aliases. These are structural ledger fixtures, not runtime station authority or fabricated source admissions. Replace the old 372-record positive boundary with exactly limit records and require a valid constructor plus exact JSON round trip.

The decoder uses the same malformed strings at exactly limit as a control: element decoding must report typeMismatch at records[0]. At limit+1, preserve the original dataCorrupted-only catch and exact description `Native station record limit exceeded.` Any other oversized error still escapes and fails. The admitted-size control does not change that oversized oracle.

## Preservation and qualification

Only three existing methods change: nativeStationRegistryRejectsDuplicateForeignAndUnboundedState, nativeStationStructuralMetadataAndRevisionLimitsAreChecked, and nativeStationDecoderRejectsOversizedRecordArrayBeforeDecodingElements. All three are unparameterized: three methods/three cases, with no retained earlier pass. Existing duplicate, foreign namespace, alias, revision, descriptor, owner, nonmutation and custody checks remain. No production, shared fixture, source catalogue, runtime admission or G04 path changes.

Strict Swift formatting, scoped Markdown lint, whitespace and source-conservation checks are author prerequisites. No build, test, native probe or diagnostic campaign ran. Matching owner compilation and focused three-case qualification plus one independent coherent review remain pending; this packet is not integration ready. Station-service qualification and the local G02 preview remain ahead in G1's queue. Formal CI, coverage, sanitizer, leak and release gates remain separate. No remote issue or PR exists.

Companion: [PR-native-station-budget-fixtures.md](PR-native-station-budget-fixtures.md).

## Compiler-only follow-up - 20 October 2026

Actual combined build977 failed before any tests ran: Swift Testing rewrote the key-path `allSatisfy` requirement into a throwing call without `try`. The same `.valid` predicate is now evaluated once into a typed Boolean with an explicit nonthrowing closure, then required unchanged. All budget, positive-control, malformed-element and exact refusal oracles remain. Original977 failure is preserved at `/tmp/elite-station-hull-budget-compile-977`; corrected matching build and the same19-method/34-case cohort remain pending, with no earlier PASS retention. The original component reviews remain; only this compiler delta needs a focused review.
