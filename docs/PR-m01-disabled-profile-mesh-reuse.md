# Reuse raw mesh storage for disabled ordinary EMP profiles

## Change

Only mesh acquisition in `SalvageCatalogue.makeProfile` changes. A disabledOrdinaryShip entry other than SH061 uses the existing raw cache result when present. All other cases keep the exact `ship.design.rawMesh` conversion. Ordinary37 profiles and SH061 remain on their previous path; the raw cache itself is unchanged. Eligibility, dictionary construction, bounds, faces, normals, section choices, tiebreaks, technology IDs, work times, full materials and texture mappings retain their existing code. [Source duplication and observed limits](ISSUE-m01-disabled-profile-mesh-reuse.md).

The disabled-only guard keeps the static graph acyclic: disabled profiles can request the raw cache, which requests only ordinary profiles; ordinary profile construction never requests that cache or disabled profiles. Immutable static initialization and Sendable mesh/array storage retain existing Swift 6 synchronization. No lock, mutable state or actor escape is added. Native cold initialization and concurrency remain unverified.

The accepted tradeoff is earlier full raw-cache initialization on an EMP-first path, including two game-nil meshes, physical SH061 geometry and dictionary storage. It can increase early allocation churn or peak. The change removes a duplicate conversion when both inventories exist; it does not remove eager profile metadata, section work or their scratch arrays. No causal, measured-RSS or sufficient-fit claim is made.

## Regression assertions

The existing catalogue Test ID appends one private helper after all previous original-texture and SH061 checks return. Every previous statement, assertion and diagnostic operation stays in order. The 63-checkpoint schedule, all 37 resolved oracles, original texture checks, actual SH061 EMP lookup, selectors, cohorts, options, budgets and internal concurrency remain unchanged. The new work occurs after haflinger-done and before the deferred body-exit; its finite extra oracle allocation and time are explicit costs.

The helper visits actual resolved catalogue records without ordinary profiles. For game-nil records it checks that EMP profiles remain absent. For each eligible record it requires the actual optional profile, checks its ID, disabled role and unit scale, and compares all six mesh fields with a fresh independent `ship.design.rawMesh` oracle, including complete texture/UV mappings. For non-SH061 entries, nested borrowed buffers verify nonempty shared vertex storage with the raw cache. The existing SH061 physical-versus-authored full comparisons remain. No unsafe pointer escapes or oracle collection accumulates across iterations. Candidate totals of 132/131 are source projections, rather than asserted native dictionary counts.

## Validation and handoff

Five focused source/model checks pass. The Python geometry and ownership projection covers the 132 resolved source candidates, the 131 sharing routes and the original fallback. Five deliberate faults are detected: duplicate vertices, dropped textures, physical SH061 substitution, an ordinary reverse cache dependency and packaged-original provenance. Exact source checks preserve all original assertions, operation order, Test IDs, checkpoints, raw-cache code and diagnostic helper. These checks are not Swift execution, asset validation, a runtime profile count, layout or RSS measurement. Scoped Markdown lint and whitespace checks accompany the frozen packet.

Actual Swift assertions, cold initialization, buffer sharing, RSS effect and `make ci` remain **UNRUN** for this packet. It stays in development/validation pending one independent source review and G1's separate actual compile/test authority. MC1 must close concrete findings and obtain passing focused evidence before integration handoff. Source/model results alone do not establish readiness.

No native build, run, profiler, resource/process probe, operator policy/session/proof write, publication or release was performed. Preserve prior failed raw attempts and counters. Any new native evaluation requires a fresh exact committed source and reviewed bindings. Full ASAN/TSAN, real coverage, leaks, final-head PR review/checks, protected merge, exact-main Sonar and release gates remain required. Diagnostic-on observations do not qualify ordinary gate-OFF execution.
