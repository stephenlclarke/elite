# fix(runtime): consolidate M01 value lifetime and validation repairs

M01's written fixes now compose with current development in PR107. They bound Commander/native-people/script-instance value storage and equality, query/settlement/cargo snapshots, physical actor adoption, station population/validation readers and the complete-content memo cache. Actor ownership, complete semantic validation and existing flat save representations remain intact. The final cache repair retains immutable full content under the existing lock; it does not substitute a hash or pointer identity for equality.

The previously local range ends at7ea67fe6. Its final holder build passed in215.073837seconds, and all five existing memo methods/five cases passed in4.756853seconds with zero failures/errors/skips. Other bounded component evidence remains in the existing per-packet handoffs and [retained diagnostic record](PR-rescue-acceptance-frames.md). Original-flight diagnostic failures remain preserved and are not relabelled as passes.

## Composition

The canonical source base ise05d18e8. There were no production-code merge conflicts. All21 M01-owned production paths remain byte-identical to the retained source before composition. Five conflict paths are resolved narrowly: preserve the equality-enabled Makefile targets alongside the reviewed local runner; use the exact effective selector union; update its count fixture; retain the current independent-runner promotion notes and common historical provisioning evidence.

The exact union is462 methods:394 retained M01-branch methods and410 current development methods, with342 shared,52 M01-only and68 development-only. No effective method is dropped or added outside this union. The runner implementation before/after the dictionary is unchanged, and the report fixture changes only its expected count. This is an inventory, not a462-method execution result.

The actual equality audit checks51 ScriptInstanceValue fields,26 ScriptEngineState fields and60 Commander fields. All25 Python audit fixtures and six report fixtures pass on this composition. Strict formatting, scoped Markdown and whitespace checks pass. Existing source review/component results are reused; actual composed-head Swift results and incremental composition review remain pending. No new local Swift build, native journey, debugger capture or broad integration/performance run was started.

## Remaining M01 scope

No genuinely unwritten code or unit case has been demonstrated in the current reviewed repair scope. This does not establish dependable playable M01 acceptance. Launch/flight/jump, real job and receiving-station delivery, once-only payment/clue, completed-save reopening and usable release remain explicit unverified acceptance criteria. Any new concrete source defect enters remediation; speculative refactors and unrelated feature work are held. See [the source-consolidation issue](ISSUE-M01-source-consolidation.md).
