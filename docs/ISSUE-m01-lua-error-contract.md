# The script host lacks Lua's non-returning error contract

Vendored `luaL_error` has a public `int`/varargs declaration, but its implementation ends in `lua_error`. The latter's paths raise through `luaM_error` or the non-returning `luaG_errormsg` and `luaD_throw`; no path returns normally. Lua itself marks `lua_error`'s final return unreachable.

The maintained output-buffer allocation guard calls `luaL_error` on NULL. Without that contract in the host translation unit, static analysis considered a return followed by a NULL write possible. PR278 added a defensive return after the error call. That return cannot execute in the actual Lua implementation. The exact-main df3 analysis cleared the reliability finding but failed new C coverage, reporting only one of four changed lines covered.

Declare the real non-returning contract at the maintained C boundary, preserving its `int` signature, varargs and external linkage. Remove the impossible defensive return, while retaining the normal conditional guard and error call. Keep vendor/public headers, allocation behavior, resource limits, error unwinding, coverage reports and quality gates unchanged. [Implementation and qualification](PR-m01-lua-error-contract.md).
