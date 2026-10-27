# Finish ASAN before thread preparation becomes eligible

Thread preparation now needs the full address preparation and shard chain. Its explicit `always()` condition permits the legitimate no-pending shard skip only when address preparation succeeded and emitted exactly `false`. Failed or cancelled address work, missing pending state and absent authorization keep thread preparation blocked.

The existing required physical aggregate still rejects blocked preparation and failed or cancelled components. The caller workflow, source and policy pins, authorization, runner labels, normal tests, coverage, TSAN, ASAN and leak gates are unchanged. No selector, helper or native code changes are included.

One table-driven fixture in the existing `WorkflowTests` class evaluates the actual job condition and exercises the actual final aggregate script for pending success/failure, legitimate no-pending skip, unexpected skip, missing or invalid pending state, cancellation, preparation failure/skip and unauthorized execution. It also checks the three dependency edges establish an acyclic address-first chain. Validation is limited to this fake fixture, actionlint, Markdown lint and whitespace checks; no native execution, compiler, API or broad test campaign is included.

This isolated component starts from reviewed `28c4a43818c6825cb2ecf5cb878df420923dd7cf`. Independent source review remains required. G1 will compose the reviewed routing and MC1 resource-evidence changes using separate test hunks, then own the coherent execution checkpoint. This component makes no native qualification or release claim. [Motivation](ISSUE-m01-address-before-thread.md).
