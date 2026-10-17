# fix(tests): evaluate Crimbo macro operands before assertions

## Result and implementation

The provider-facts test evaluates its throwing query before requiring the returned optional. The two electrical-resource tests evaluate their mutating drains before asserting the Boolean result. All calls retain their exact arguments, original ordering and once-only execution; the assertions and expected-throw closures retain their meaning.

## Scope and validation

Only the three compiler-reported expressions in `NativeCrimboProviderTests.swift` and `NativeCrimboRegistryTests.swift`, plus this [issue/PR pair](ISSUE-native-crimbo-test-macros.md), change. The three Crimbo test files were audited for remaining direct mutating and throwing macro calls. Existing explicitly throwing comparison assertions, pure snapshot capture and the compiled nonmutating rebind helper remain intact. No production source or runtime observer work changes.

Formatter/parser, scoped strict lint, Markdown and diff/scope checks passed. The actual diagnostics were inspected in `/tmp/elite-native-crimbo-lifecycle-focused-315/candidate-315-attempt-01.log`. No compiler, typecheck, test discovery/execution or native job ran in this source worker. G1 owns the eventual meaningful affected rerun.

Any eventual project PR requires actual completed clean `@codex review` cycles and passing final-head required checks and approvals before protected merge, without bypass.
