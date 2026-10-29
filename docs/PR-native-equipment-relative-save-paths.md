# test(fixtures): unify native equipment save path keys

## Changes

Native equipment publication checks could not locate the pointer in the collected file tree because the collector used absolute-string slicing while the new consumer assumed a leading slash. A single private helper now resolves symlinks and standardizes both root/candidate URLs, requires strict component-prefix containment and returns a relative path with no leading slash. The collector rejects duplicate canonical keys instead of overwriting a file entry.

The collector and every publication/replay consumer use that helper: pointer lookup, exact four added generation paths, each chunk hash lookup and post-commit pointer lookup. Original pointer/tree snapshots remain immutable. All file bytes, strict independent Commander/world expectations, schema/codec/new-generation checks, old-generation conservation, exact four added files, actual hashes and explicit stale replay with whole checkpoint equality remain required. No checkpoint is accepted before those positive checks. No observed key or loaded Commander supplies a replacement oracle.

## Scope and verification

The exact parent is `e1f952b1ebdbf7373ffeade0c2a7ecf84c9ca0a3`. Three files change: `NativeEquipmentViewTests.swift` and this issue/PR pair. Only `recoveredSaveFiles`, `verifyNativeEquipmentPublication` and `verifyNativeEquipmentPostcommitRefusal` change, with one private path helper added. Eight static collector calls serve all eight existing fixture methods/eight cases, including five previously passing methods. All method bodies, bootstrap construction, existing domain expectations and other original source bytes remain byte-identical. The NativeWork reference, production, legacy station leaf and G1 scopes remain unchanged; all earlier refs are preserved.

Only source formatting/parsing, strict lint, Markdownlint and static exact-scope/assertion-effect/caller/selection/hash checks run here. No compiler, typecheck, discovery, tests, build, native/UI/media, GitHub, push, merge or Sonar jobs run. Root must review this child before execution under G1's lease. The three 343 failures reached strict semantic publication checks but not complete file/replay verification; no full acceptance is claimed. Host-specific alias offset details were not dumped and remain an inference.

Eventual PRs require completed clean `@codex review` cycles, fixes and repeat review for every actionable finding, required final-head checks and approval, and protected merge without bypass.
