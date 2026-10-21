# Validate stable module identities and beneficial upgrade directions

## Recorded failures and authority

Root verified that `equipmentModuleTemplatesHaveStableMonotonicValidatedDefinitions` terminated failed after 125.934 seconds during validation 352 at `25574f2e1ebfc26c52fa33700eaeac9e48db853b`. Its eight observed issues were one three-family registry assertion, three universal ID-prefix assertions and four raw-axis monotonicity assertions. The fixed observed fragment is `/tmp/elite-full-review-ci-352/ci-352.log` lines 3752-3774, SHA256 `43bafa1351f76f6dbfc778fb40e59cee075b8de3021da4e2a5bdbc2dfb81de01`. The CI log remains live; this is not a final whole-log hash or overall CI result.

The authoritative registry includes shield, navigation, energy and hyperspace-drive families. Original shield/navigation/energy IDs use their established prefixes. Drive template identities separately retain the `hyperspace-drive` family and serialized IDs `basic`, `intermediate`, `advanced`, version one. The local prefix convention is not universal and does not justify renaming persisted drive identities or stock origins.

User FR-026 requires ordinary activation times 10, 5 and 1 seconds; later FR-027 sets mass-lock factors 100%, 80% and 60%. Lower times and distances are beneficial. `ComponentAxis.higherIsBetter` and the production progression validator already account for lower-is-better axes. The older three-energy-grade plan is superseded by FR-020's explicit Elite Energy Unit at four times normal; the fourth energy grade and revision two remain legitimate.

## Required correction

Require the exact four-family order, exact ordered stable IDs within each family, matching identity family/version, uniqueness, available display names and existing revisions. Keep the complete original shield ID assertion. Every actual grade must still pass the real 500-basis-point `moduleQuote` through the full production definition validator; no family or grade is skipped.

Adjacent grades must retain identical required axes, improve or preserve every required axis in its declared beneficial direction, and strictly improve at least one. Require the independent lower-is-better jump-spool direction and exact 10/5/1 stock seconds. This changes no production identity, migration, ordinary positive floor, mass-lock policy or upgrade calculation. Existing drive policy and legacy module tests remain unchanged.

## Scope and validation

The isolated parent is `25574f2e1ebfc26c52fa33700eaeac9e48db853b`. Only this existing test method in `EquipmentModuleTemplatesTests.swift` and this issue/PR pair change: one method/one case, no new test or helper. Shared `moduleQuote`, every other method, production and G2's separate effective-equipment audit remain untouched. All prior refs are preserved.

Root explicitly authorized this cold managed-worktree exception after the method's terminal failure. Canonical source/HEAD/inputs remain frozen during 352. Formatting/parsing, strict lint, Markdownlint and static assertion-effect/scope/hash/selection checks are the only local validation; no compiler, discovery, tests, build, native/UI/media or GitHub jobs run. Root reviews the frozen leaf; composition/rebuild waits until 352's terminal artifacts are preserved. See the [PR handoff](PR-module-template-directional-benefits.md).
