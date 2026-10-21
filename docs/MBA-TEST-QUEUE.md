# MBA pushed-commit test queue

The Orchestrator and MBA tester maintain this queue. Only G1 implements features and fixes. Historical source archives preserve work and are not a queue of hundreds of feature deliveries. Every subsequent feature push must have an exact-SHA row here, including corrective commits.

| Exact commit | Scope | Status | Evidence / next action |
| --- | --- | --- | --- |
| `41c15aed9d2684cc2708077a16f6b8aef576be31` | Canonical baseline and all-source checkpoint index; W04 locally integrated, collision repair unfinished | Assigned: baseline build and affected W04 tests | [Issue #22](https://github.com/stephenlclarke/elite/issues/22) closed after human-authorized licence acceptance and successful licence check. Run on MBA with one job; no application-test result yet. |

Next feature: G1 owns the M01 collision correction. Add its exact SHA and affected test command when pushed. Never invent a commit ID or mark an unrun case as passed. On a confirmed failure, link a GitHub issue with reproduction, actual/expected behavior and a proposed solution; do not fix source on the MBA. Reuse unaffected results and batch broad integration testing.
