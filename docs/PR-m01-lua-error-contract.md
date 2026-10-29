# Declare the script host's actual non-returning Lua error contract

This surgical child starts at exact main `df3fb56952d83b36aaa012a873c59af2ff007a8c`. `MissionScript.c` adds a translation-unit-local redeclaration of `luaL_error` with the identical `extern int` signature and varargs plus GNU `__attribute__((noreturn))`. The existing output-allocation NULL guard and error call remain readable and unchanged; only the unreachable defensive return is removed. [Problem](ISSUE-m01-lua-error-contract.md).

## Contract and compatibility

The source chain is `CLua/lauxlib.c` `luaL_error` to `lua_error`; `CLua/lapi.c` sends both cases to `luaM_error` or `luaG_errormsg` and explicitly labels its final return unreachable. `CLua/ldebug.c` marks `luaG_errormsg` `l_noret` and calls `luaD_throw`, whose exits throw/longjmp, rethrow or terminate. `CLua/llimits.h` already uses the GNU noreturn attribute convention. The host is a C translation unit in the macOS 14 package; it does not add a C++ exception specification.

The declaration preserves return type, parameters, calling linkage and vendor/public bytes. It adds no `nothrow`, `noexcept`, `pure`, wrapper or abort. All Lua setup, allocation, protected calls and error unwinding remain in C. No allocator seam, global failpoint, callback, test-only API, budget change or source-line condensation is introduced.

## Regression and actual qualification boundary

The existing evaluator methods remain byte-for-byte unchanged. Focused qualification can reuse `luaExecutesProceduresAndExplicitDataWithoutHiddenState`, `luaPreservesSignedIntegerLimitsAndRejectsInvalidOutput` and `luaContainsLoopsAllocationRecursionAndCompilerBudgets`. These exercise real successful evaluation, malformed/cyclic/nonfinite output, explicit errors, recursion, instruction limits, heap/allocation budgets and output limits through the protected C host. Existing sandbox, wire and native leak checks remain available for required CI.

These tests do not force the raw output `realloc` to return NULL. This change claims the truthful compiler/analyzer contract, not new OS-allocation-failure coverage or execution of an impossible return. Runtime behavior is intended to remain unchanged; no extra test is added merely to mirror a declaration.

Source-only checks verify the exact three-path scope, identical vendor/public/evaluator bytes, the actual non-return chain and a byte-exact restoration to parent after undoing only the declaration and return removal. Markdown and whitespace checks pass. G1 owns the actual C declaration-compatibility build, focused existing evaluator execution, required CI and fresh Sonar result. Those checks are pending on this packet; source inspection does not establish compiler acceptance, analyzer recognition or a passing quality gate. No compiler/native/probe/media execution, gate/baseline/report change, push, merge or release occurs here.
