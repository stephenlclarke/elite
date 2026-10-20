# fix(missions): share Original and Wayfarer reservation capacity

## Change

Enforce a maximum of three active accepted Original contracts plus Wayfarer services using existing authoritative instance jobs and native custody. Each instance contributes at most one slot. Terminal outcomes free slots; story-only state and legacy project contracts do not occupy Original service capacity.

Original contract admission checks the shared cap after its existing accepted-instance return and before money or custody changes. Native Wayfarer quotation checks the same cap, so pickup's existing re-quote also checks it. Commander contract validation and native Wayfarer engine validation use the same derived policy, including containers without Wayfarer stock. Existing provider-specific restrictions and protected publication remain intact. No new persisted field or save version is introduced.

## Validation

Six focused pure/actor methods cover mixed classification, terminal release, duplicate and stale confirmation, fourth quote/confirm refusal, native Wayfarer quote refusal at capacity, stricter provider limits, actual generic-contract cancellation, writer failure/retry, current reload, and checksum-authenticated over-cap save rejection. Synthetic Wayfarer custody is only a classification input; it does not claim physical pickup, docking or a valid native service save. Owner focused evidence qualifies all six methods/six cases in aggregate: five unchanged methods passed on 6341870561157ed6f53c0861b8282e9a4b53b7d2; the one corrected cancellation method passed on 45ccf1c800585933c99fc7f7e5866d51ae65f22d. This is retained five plus corrected one, not a new single six-case passing batch. The correction only preserves the generic contact dialogue's existing Confirm selection instead of toggling it to Back. The original failed run and its three assertions remain recorded. The corrected run closed cleanly with frozen source, preferences and test binary unchanged. G1 independent bugs/performance/style review completed CLEAN after these owner passes; its receipt and integration provenance are recorded in the completion ledger.

## Compatibility and remaining work

Existing valid containers at or below capacity retain their format. Over-cap current saves are refused rather than silently dropping accepted work. This does not publish Wayfarer content, close stable-offer lifetime or artwork work, repair docking, or establish M05/M09 playable completion. No broad native flight or integration batch is included. Related issue: ISSUE-original-service-reservation-cap.md.

## Executor evidence

The initial relocated compiler-module-cache failure and the subsequent 600-second build timeout with owned-process cleanup remain preserved. Successful incremental builds and matching focused executions used the existing CLT/runtime/search paths, one compiler job and default worker stacks. No flight or docking loop ran. The working absolute MBA source/scratch paths are retained for the future approved queue; source snapshots, commits and proof records must be preserved and all owned processes closed before applying another frozen source there. Do not relocate its module cache for each future task.
