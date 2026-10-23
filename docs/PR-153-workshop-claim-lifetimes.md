# Bound empty workshop validation before full claim policy

## Motivation

[Issue153](https://github.com/stephenlclarke/elite/issues/153) identifies the owned workshop validator path during original inventory browsing in a required quality failure. Empty script instances do not require either original claim loop.

## Implementation

Use the existing typed scriptInstancesAreEmpty reader in a thin noninline validateClaims entry. An empty instance dictionary returns the original true result. Every nonempty engine enters a noninline helper containing the entire original child and reverse-parent policy unchanged. There is no broader claim classification, default-state mutation, save schema or authority change.

## Validation

Formatting and diff hygiene pass. Four original methods/cases cover actual inventory browsing, valid service/return, reverse custody/stock-window refusal and schema/orphan/unknown claim rejection. Focused execution and independent actual-source/result review are pending. See [the issue evidence](ISSUE-153-workshop-claim-lifetimes.md) for exact historical failure limits.

## Compatibility and remaining limits

Original complete policy and lazy empty/default semantics remain. No assertion weakening, stack change, concurrency change or extra diagnostic run. Earlier151/154 qualification retains its source-specific receipts; final full VM and required quality checks, native M01 acceptance and release remain separate.
