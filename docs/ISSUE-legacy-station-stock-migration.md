# Keep station-absence fixtures genuinely legacy

## Source-backed cause

The bounded raw-bootstrap audit at `26ae50032788bd1f65653e53ef0b89c55e88bc0f` identified two malformed positive legacy methods/three cases. `verifyLegacyStationAbsence` and `verifyLegacyWithoutStations` called current equipment preparation before writing raw JSON. Preparation creates version-three owned equipment and a real modular drive; the raw loader correctly rejects that current payload before reaching station-absence assertions. Explicit null station/custody fields do not authorize a current drive. Audit: `/tmp/elite-g2-native-raw-bootstrap-audit/review-26ae500.json`, SHA256 `0f28a647b8fbe234a702230d8b9593a09a51a8a808277899bc4095726c3259fd`; all 14 pinned source hashes were verified. This is a source diagnosis, not a recorded native run.

## Required behavior

Capture the genuine fresh scalar Commander before any preparation. Require valid legacy Pulse-only equipment, no owned inventory/history/version and no serialized modern ownership, drive, electrical, mining, EMP or alien fields. Encode this original value without stripping fields or substituting a current versioned writer. Preserve the absent-field and explicit-null variants; inspect the latter's null station and RRS fields explicitly.

After actual raw load, independently reconstruct the exact stock migration. Only allocated owner/hull/item IDs are observed from the result. Derive every node, fitting slot, standard foundation provenance, component origin/statistics/grade and legacy missile entitlement from supported stock definitions and the original seed. Require five exact foundations, the original missile count in exact pylons, zero inventory/history revision, no paid receipts, correct owner/hull bindings, unique IDs and one reserved born-stock Basic drive. Independently migrate the legacy-unworked mining ledger at the original galaxy/system.

Compare the entire migrated Commander with the original input plus only this reconstructed inventory/history/version, stock-drive equipment mirror, laser/storage mirrors and legacy mining pin. The explicit-null case captures its independently constructed raw Commander before loading, preserving the input's empty-contract representation without normalizing observed loaded fields. Preserve every existing docked, no-station, no-arrival/event, no-service-authority, cash/cargo and custody refusal assertion. Require original raw bytes and all source-root files unchanged.

## Scope and validation

The separate parent is frozen publication leaf `67cd278835c7df2cc6147ab3812302b0d3382daf`; that leaf and all earlier refs remain preserved. Only the two narrowly owned legacy helpers in `NativeStationPersistenceTests.swift` and `RawNativeSaveAuthorityTests.swift`, three shared test-only functions in the latter file and this new issue/PR pair change. Two existing test methods/three expanded cases are affected, with both method bodies unchanged. Intentional raw negative cases, current versioned paths, startup reference, production, native equipment publication helpers and G1 scopes remain byte-identical.

Only formatting/parsing, strict lint, Markdownlint and static scope/assertion-effect/hash/selection checks run here. No compiler, discovery, test, build or native job runs. Root must review the frozen child before scheduling execution; this follow-up does not block the original 342 selection. See the [PR handoff](PR-legacy-station-stock-migration.md).
