# Borrow the Commander during navigation binding's active-instance projection

## Change and preservation

Base is exact CI-728 source `4f5b1aae77accf7c02b0b37992844e0cf20949ed`. Only `ScriptNavigationTradeState.swift` and these paired notes change. Root relayed G1's production-file ownership agreement before editing. Work uses the separate `fix/navigation-binding-commander-projection` checkout; the old `99e2a9a0` worktree and refs remain frozen and clean.

`production(in:)` obtains the same active-instance array from one private `@inline(never)` helper accepting `borrowing Commander`. The original predicate still runs eagerly over the same dictionary values. The unchanged caller then compactMaps saved navigation records and takes the first matching awaiting-buy, held, sold or lost stage in the same order. A selected retained record still goes through `production(for:)`; failure there returns nil and cannot fall back to another route. Only absence of a qualifying retained record reaches the unchanged selected-route lookup. No sorting, lazy chain, caching, additional lookup or authority change is introduced.

`ScriptDirector.scriptUnavailable` and its evaluation/refusal order remain untouched, including explicit-binding handling. Original world/coordinate/endpoint validation, selected-route matching, Swift 6 isolation, campaign acceptance and transactional rollback are unchanged. The helper is a narrow lifetime boundary, not a Game/COW or collection redesign.

## Evidence and regression scope

Substituting the helper's exact borrowed field projection and removing its wrapper/separator reproduces the complete base production file byte-for-byte. Proof is `/tmp/elite-ci728-navigation-binding-source-proof.json`. The complete original `ScriptCourierPersistenceTests.swift` and `ScriptNavigationTradeTests.swift` remain unchanged by this leaf. G2's separate terminal-load method repair has no file overlap in this commit.

The exact primary regression is both existing variants of `courierScriptStateInoutRealChildAndEventAppendPreserveContextsAndSibling(nested:)`: real campaign acceptance must reach the native child, event append, context and sibling checks on the original stack. Existing binding tests retain actual-original-world/content rejection and closed-history selected-route fallback checks. G1 owns the smallest affected selection and required release gates; no new author execution or broad repeated batch is requested.

Strict Swift formatting/lint, scoped Markdown lint and whitespace checks pass. The exact crash and binary hashes are verified; retained old-function disassembly is `/tmp/elite-ci728-navigation-binding-existing-disassembly.txt`. The old binary shows the whole Commander copy before filtering. The new code is uncompiled and unexecuted; copy elimination, frame reduction, stack margin and runtime repair remain unestablished. No compiler, native test, debugger, profiler or executable probe runs on the author side. No check, test, stack/concurrency budget, mission content or availability policy is weakened.

Deliver the frozen ref to Root for G1's independent review and integration into the sole release-blocker batch. This is not a successful CI, usable-app or release acceptance claim. See the [issue](ISSUE-navigation-binding-commander-projection.md).
