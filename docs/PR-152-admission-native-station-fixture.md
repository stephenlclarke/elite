# Prepare native station baselines for admission tests

## Motivation

[Issue152](https://github.com/stephenlclarke/elite/issues/152) shows that three original admission tests count a pruned scene before production restores its registered native station. Hard-coded counts fail even when the requested admission and replay behavior is correct.

## Implementation

Use a test-only native population preparation helper in the three failed methods. Validate present current station bindings, capture the complete body baseline, retain exact original actor/body values and assert exact requested additions. Stale and atomic refusals retain complete bodies and independently assert unchanged allocator state. Keep the original success, transform, replay, population-limit and partial-admission assertions. No production or shared fixture behavior changes.

## Validation

Formatting and diff hygiene are checked. Four unresolved original methods will run with the151 production change; the two unchanged empty/adoption methods reuse their actual d5 result. Independent source/result review is pending. See [the issue evidence](ISSUE-152-admission-native-station-fixture.md) for original failure limits.

## Compatibility and remaining limits

Tests only; no save schema, authority or gameplay change. Earlier duplicate/intersection and safety tests keep their original setup. This fixture correction does not explain signal10 or historical144. Full VM/required quality and native M01/release remain separate.
