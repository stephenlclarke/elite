# fix: borrow bodies while collecting gameplay mesh overrides

Replace owned body iteration with original-order array indices and a non-inlined predicate accepting a borrowed body. Preserve catalogue, rock, salvage-lot, native-station and alien-seeker checks in their original short-circuit order. The same body ID and unchanged `gameplayMesh(for:)` produce each override, including original duplicate-key overwrite behavior. No energy filter is added.

Only `GameplayWeapons.swift` changes executable code. The collision query, geometry, mesh provider, emission, damage, EMP behavior, actor ownership and schema are unchanged. RRS fixture source `a4698c5a` and G2's StationApproach correction remain separate composition inputs.

Strict Swift formatting and patch whitespace are checked. First qualification is the unchanged native Cobra two-pulse EMP test; two existing zero-ray/sweep and malformed-geometry collision tests follow on the same composed artifact. Build/tests are UNRUN, independent review is pending, and no frame improvement or integration readiness is claimed. Root routes the frozen patch to G1 for its shared936 candidate; the owner performs no cold build or diagnostic campaign.
