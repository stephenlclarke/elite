# Encounter admission lifetime phases

## Motivation

[Issue151](https://github.com/stephenlclarke/elite/issues/151) identifies the owned stopped admission predicate path in the original authored-board travel/delivery/repeat test. Early admission checks share a function frame with later request construction and persistence temporaries.

## Implementation

Use a thin noninline entry for the original empty-plan predicate and a noninline nonempty phase containing the complete original remainder. Forward the same plan value. Preserve all original guards, operation order, receipts, atomicity, idempotency, identity allocation and state publication. No per-request or general admission policy is changed.

## Validation

Formatting and diff hygiene pass. Six directly affected unchanged methods/cases retain empty/adoption, full preflight, atomic/partial refusal, replay and original mission delivery assertions. Execution and independent actual-diff/result review are pending. [The issue evidence](ISSUE-151-encounter-admission-lifetimes.md) preserves exact failure scope and missing guard-mapping limits.

## Compatibility and remaining limits

No save schema, actor isolation, equipment, missile resource or mission behavior changes. No stack enlargement, concurrency change or assertion weakening. The current full VM and required quality runs remain separate, and historical144 origin is unproved. Native M01 and release acceptance remain open.

The first focused invocation at d5d6da32556fd73578d6ac081453927a56780d06 failed: build94.32s, total110.009920s, process exit1. Only the two EmptyEncounterAdmission methods completed successfully. Three GameplayAdmission methods recorded five hard-coded body-count assertion failures; actual admission restores registered native stations after the fixture removes their bodies. The original authored-board method started but has no completed result. The helper also terminated with signal10 and XML remained unfinished52bytes. No fresh attributable normal crash report was found, so this run does not establish a new fault location or guard mapping. Evidence: `/tmp/elite-151-admission-lifetimes-units-result.json`, its log and unfinished XML. Source151 remains unqualified; no six-method pass is claimed.
