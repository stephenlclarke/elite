# Sonar main analysis blocks release on two findings

Exact main20f8c936 passed both full3403-method normal phases and its zero-leak probe. Sonar accepted that exact revision but failed reliability and security ratings. Coverage90.3%, duplication2.9%, maintainability and hotspot review passed.

C rule S3807 follows a null realloc result past luaL_error because its public declaration returns int. Bundled Lua actually raises through lua_error, luaG_errormsg and luaD_throw into the evaluator protected call. Clarify that local branch without changing the allocation, output budget, serialization or error cleanup contracts.

Swift rule S6418 flags the public authoritySHA256 generated content digest. Its literal equals SHA256(config/flight-controls.json); it is not a credential. Use an explained false-positive disposition for that exact issue, retaining the rule, generated API and public provenance value. No analysis exclusion or gate change is needed.
