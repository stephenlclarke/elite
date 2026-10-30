# Remove redundant returns before non-returning Lua errors

[Issue 287](https://github.com/stephenlclarke/l337/issues/287) records six maintained-source Sonar c:S1763 findings at the error exits in `Sources/MissionScript/MissionScript.c`. The existing `luaL_error` declaration is non-returning; each call throws through Lua. Its surrounding return keyword cannot execute.

Remove only the six redundant return keywords. Preserve the declaration, calls, conditions, error messages, interpreter limits and all existing assertions. No suppression, numeric or API change is required. The successful 4d0903d72683f3b031d5deafd74056301803d2f2 main results remain scoped to that commit; the correction needs its own review and required qualification before release.
