# Require separate fitted and held inventory headings

## Motivation

[Issue155](https://github.com/stephenlclarke/elite/issues/155) identifies an original test expectation left behind by maintained fitted/held section grouping. The browsing method completes and fails only that obsolete heading.

## Implementation

Replace the one removed combined-label assertion with two independent exact current-label checks. Both must appear only on inventory, and neither on status. All original mount, row traversal, bounds, scrolling and equipment shop assertions remain unchanged. Tests only; no UI rollback or production policy change.

## Validation

Formatting and diff hygiene pass. Only the original affected browse method runs; three unchanged153 workshop domain results retain their exact677 source evidence. Final result and independent review are pending. See [the issue evidence](ISSUE-155-inventory-section-heading-fixture.md).

## Compatibility and remaining limits

No save, authority, gameplay or user interface change. No assertion is removed or relaxed. Full VM/required quality and native M01/release acceptance remain separate.

At exact59f254dc75132594de8bd91263ca76078986623c, the corrected original inventory browse method passed100.885971s, with process exit0, complete one-row XML and zero failures/errors/skips. Compile49.65s/total156.162784s on local Swift Testing6.4.1 arm64. Evidence `/tmp/elite-inventory-headings-browse-units-result.json`, raw log and `-swift-testing.xml`. All original mount, complete row traversal at three widths, viewport bounds, page scrolling and shop assertions passed; the two maintained headings are independently required iff inventory.

The three workshop domain passes remain at source67761181 with unchanged WorkshopSavee23b0630, while this original browse pass is at59f254dc. These source-specific receipts are reused without inventing an aggregate four-row passing process. Independent actual-source/result review closed153 and155 on these exact source-specific criteria; full VM/required quality/native M01/release remain separate. No further passed-case execution or candidate/media build is needed for this documentation composition.
