# fix: remove redundant returns before non-returning Lua errors

Remove six redundant return keywords before the already non-returning `luaL_error` calls. Calls, conditions, messages, declaration and every other production byte stay unchanged. This resolves the six c:S1763 findings without changing Lua error behavior.

Existing `ScriptEvaluatorTests` cover invalid scalar conversion, missing handler/module results, malformed wire data, sandbox refusal, execution budgets and interpreter success/abort lifetimes. Their source and assertions remain unchanged. Source review and correction execution are pending; no new test pass is claimed. The prior main run passed 3,431 methods with six declared skips, zero failures, 90.49% final coverage, zero leaks and the exact-main Sonar gate, while still reporting these six actionable findings. No release plan was generated for that source.

See [the issue](ISSUE-287-lua-error-control-flow.md). No later targeting implementation, generated media, review-bot request, workflow or permission change is included.
