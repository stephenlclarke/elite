# Older cue test still expects authenticated rescue pods to be ordinary

Live full CI 566 at `bb50a4262cc647f8815de7c0e0d2e5aa3f271087` recorded two issue headers in `disabledHostileTurnsOrangeImmediatelyWhileCrewStillAboardInEveryStyle`: lines 71/72 expected `.ordinary` and `OCCUPIED ESCAPE POD - PROTECTED` after the genuine EMP producer ejected original crew. `/tmp/elite-full-review-ci-566/live-issue-headers.json` is a live partial packet, not final CI acceptance or a complete issue ledger.

These expectations predate the approved native pod rescue behavior in `23de94d8` and [the rescue protection handoff](PR-native-pod-rescue-protection.md). Authenticated original EMP pods remain protected against ordinary harm while the cue is orange, independent of installed tools or free hold. Rescue selection and collection separately retain equipment, capacity, geometry, custody and publication checks. A pod with the required fittings and free hold displays `OCCUPIED POD - SINGLE 1T RESCUE UNIT`; protection is not a claim that the human unit is uncollectible.

The actual test fixture grants Salvage Module and Fuel Scoops, drives the real disable/ejection boundary and has available hold. Current pure classification/status already implement the approved requirement. Correct the obsolete test expectations and assert the actual custody/protection preconditions, without changing production classification or weakening other cue cases.

[Fixture correction](PR-escape-pod-cue-fixture.md).
