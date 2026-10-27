# Bound empty workshop validation before full claim policy

## Motivation

[Issue153](https://github.com/stephenlclarke/elite/issues/153) identifies the owned workshop validator path during original inventory browsing in a required quality failure. Empty script instances do not require either original claim loop.

## Implementation

Use the existing typed scriptInstancesAreEmpty reader in a thin noninline validateClaims entry. An empty instance dictionary returns the original true result. Every nonempty engine enters a noninline helper containing the entire original child and reverse-parent policy unchanged. There is no broader claim classification, default-state mutation, save schema or authority change.

## Validation

Formatting and diff hygiene pass. Four original methods/cases cover actual inventory browsing, valid service/return, reverse custody/stock-window refusal and schema/orphan/unknown claim rejection. Focused execution and independent actual-source/result review are pending. See [the issue evidence](ISSUE-153-workshop-claim-lifetimes.md) for exact historical failure limits.

## Compatibility and remaining limits

Original complete policy and lazy empty/default semantics remain. No assertion weakening, stack change, concurrency change or extra diagnostic run. Earlier151/154 qualification retains its source-specific receipts; final full VM and required quality checks, native M01 acceptance and release remain separate.

At source677611811b978e7ae99a3aff3735aacdfa683c4f the four-method run completed without a helper crash and produced complete XML: exit1/176.990774s/build70.61, one failure/zero errors/skips. All three workshop domain methods passed (closed schema9.335s, valid Renas service/return9.428s, reverse custody9.488s). Original inventory browse completed102.485809s and failed only its removed combined heading expectation; every other mount, traversal, viewport, scroll and shop assertion completed. Evidence `/tmp/elite-153-workshop-claims-units-result.json`, raw log and complete Swift Testing XML. These are three domain passes and a failed browse result, not an aggregate pass.

The exact test-only heading correction is separate155: require both maintained fitted and held headings on inventory and neither on status. Retain the three unchanged workshop passes at677, and run only the corrected original browse method. No UI rollback, validation weakening, mission/NPC replay or synthetic combined XML is needed. Source153 remains unchanged during that test-only correction.

At exact59f254dc75132594de8bd91263ca76078986623c, the corrected original inventory browse method passed100.885971s, with process exit0, complete one-row XML and zero failures/errors/skips. Compile49.65s/total156.162784s on local Swift Testing6.4.1 arm64. Evidence `/tmp/elite-inventory-headings-browse-units-result.json`, raw log and `-swift-testing.xml`. All original mount, complete row traversal at three widths, viewport bounds, page scrolling and shop assertions passed; the two maintained headings are independently required iff inventory.

The three workshop domain passes remain at source67761181 with unchanged WorkshopSavee23b0630, while this original browse pass is at59f254dc. These source-specific receipts are reused without inventing an aggregate four-row passing process. Independent actual-source/result review closed153 and155 on these exact source-specific criteria; full VM/required quality/native M01/release remain separate. No further passed-case execution or candidate/media build is needed for this documentation composition.
