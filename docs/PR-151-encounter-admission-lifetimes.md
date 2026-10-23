# Encounter admission lifetime phases

## Motivation

[Issue151](https://github.com/stephenlclarke/elite/issues/151) identifies the owned stopped admission predicate path in the original authored-board travel/delivery/repeat test. Early admission checks share a function frame with later request construction and persistence temporaries.

## Implementation

Use a thin noninline entry for the original empty-plan predicate and a noninline nonempty phase containing the complete original remainder. Forward the same plan value. Preserve all original guards, operation order, receipts, atomicity, idempotency, identity allocation and state publication. No per-request or general admission policy is changed.

## Validation

Formatting and diff hygiene pass. Six directly affected unchanged methods/cases retain empty/adoption, full preflight, atomic/partial refusal, replay and original mission delivery assertions. Execution and independent actual-diff/result review are pending. [The issue evidence](ISSUE-151-encounter-admission-lifetimes.md) preserves exact failure scope and missing guard-mapping limits.

## Compatibility and remaining limits

No save schema, actor isolation, equipment, missile resource or mission behavior changes. No stack enlargement, concurrency change or assertion weakening. The current full VM and required quality runs remain separate, and historical144 origin is unproved. Native M01 and release acceptance remain open.
