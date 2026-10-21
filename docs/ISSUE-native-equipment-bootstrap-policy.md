# Correct native equipment fixture storage and fitted jump timing

## Recorded failures

Combined validation 339 completed all 46 methods/57 cases at `a6a69d48abc657e96295baa2ca6326b8a37fb6d4` without a crash or timeout. It failed seven issues in six methods; G1 owns the separate EMP failures. This leaf addresses the jump countdown and two recovery methods sharing the native equipment fixture. The jump's sole issue was `jumpCountdown == 15`, not a whole-Commander comparison. Both recovery methods caught `invalidCommander` before their fixture opened. Raw log: `/tmp/elite-emp-and-fixture-interruption-focused-339/candidate-339-attempt-01.log`, SHA256 `cabaf09b92a314ddab77c82f9879c339c74beac5f21868c767e03e32d1bf1ee9`.

## Causes and required behavior

XYZZY fits an actual Advanced drive with a one-second stock spool and Military navigation with a multiplier of one. The native policy multiplies those values; the hull's former 15-second timing is not the fitted drive's countdown. Require the actual owned devices, component grade/statistics and one-second timed policy before checking the countdown. Preserve the original range/fuel refusal, finite fuel debit, actual arrival, versioned save/read and entire restored Commander checks.

`NativeEquipmentFixture.open` encoded current version-three owned equipment as raw JSON, then called the deliberately legacy-only raw loader. Its modular-drive guard correctly refuses that input. All eight callers supply current owned state. Bootstrap those fixtures through actual canonical versioned saving and strict reading, preserving every supplied Commander field. Independently reproduce the intended docked system/market/max-resource scene and permit only documented prepare/mirror, mining-policy and calendar publication in the expected Commander.

Capture the actual versioned pointer and every original generation file. Require the complete independently expected Commander after the real delegate load and preserve exact files across initial painting and read-only actions. Keep semantic Commander JSON snapshots separate from disk save encoding. No header stripping, raw guard waiver or production timing change is permitted.

## Scope and validation

The exact parent is frozen `a74e6056fee8e24888d261b0415711814236a3d0`. The two test files affect nine existing methods/nine cases: eight shared fixture callers plus the jump test. All eight caller bodies and all other test regions remain unchanged. This issue/PR pair is the only other scope. No production or G1 EMP source changes. See the [PR handoff](PR-native-equipment-bootstrap-policy.md).

Only source formatting/parsing, strict lint, Markdownlint, assertion-effect and scope/hash checks run here. Root reviews the frozen leaf before G1 executes an approved selection. Validation 339 remains failed; completed historical/current scopes and all prior refs remain preserved, with no new runtime acceptance claimed.
