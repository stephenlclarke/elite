# fix(script): make the output allocation error exit explicit

The output writer now returns immediately after luaL_error when realloc returns null. Actual Lua errors already unwind through the protected call, so successful writes, budget checks, original allocation ownership and error cleanup are unchanged. The local exit makes the null path explicit to the C analyzer; no vendor annotation, suppression or new failure hook is added.

Existing ScriptEvaluator tests cover successful serialization, invalid output, Lua allocation/output budgets and sandbox error handling. They do not force an operating-system realloc-null result. Their fresh execution and the actual main Sonar scan remain pending; prior full normal and zero-leak results are retained separately. The Swift digest finding receives a precise documented false-positive disposition after source review, without changing its generated name/value or weakening the rule.

Scope is this C branch, paired notes and the completion ledger. Final-head review/checks and ordinary protected merge remain required. Signed release remains pending exact-main quality and Sonar. See [the issue](ISSUE-sonar-output-allocation-flow.md).
