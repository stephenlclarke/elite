# Prepare native station baselines for admission tests

## Motivation

[Issue152](https://github.com/stephenlclarke/elite/issues/152) shows that three original admission tests count a pruned scene before production restores its registered native station. Hard-coded counts fail even when the requested admission and replay behavior is correct.

## Implementation

Use a test-only native population preparation helper in the three failed methods. Validate present current station bindings, capture the complete body baseline, retain exact original actor/body values and assert exact requested additions. Stale and atomic refusals retain complete bodies and independently assert unchanged allocator state. Keep the original success, transform, replay, population-limit and partial-admission assertions. No production or shared fixture behavior changes.

## Validation

Formatting and diff hygiene are checked. Four unresolved original methods will run with the151 production change; the two unchanged empty/adoption methods reuse their actual d5 result. Independent source/result review is pending. See [the issue evidence](ISSUE-152-admission-native-station-fixture.md) for original failure limits.

## Compatibility and remaining limits

Tests only; no save schema, authority or gameplay change. Earlier duplicate/intersection and safety tests keep their original setup. This fixture correction does not explain signal10 or historical144. Full VM/required quality and native M01/release remain separate.

At18fb5976 the three corrected admission methods passed individually with no assertion issues: stale8.765s, successful admission/replay8.769s and atomic/partial8.796s. The batch nevertheless failed with the separate original mission signal10 and unfinished XML; no four-method pass is claimed. Two additional consumers of the same fixture, duplicate/intersection and unsafe-point refusal, now also prepare real native population and retain complete baseline bodies plus independent allocator checks after every refusal. All original refusal predicates remain. The general fixture and other methods stay unchanged.

A subsequent source-backed151 production preflight/body split affects nonempty admission, so the final affected selection includes these five admission methods, original mission and existing actual-request/adoption method (seven methods/cases). The unchanged empty-plan/no-effects case retains its actual d5 pass; no synthetic aggregate XML is claimed. Final focused execution and independent result review remain pending.
