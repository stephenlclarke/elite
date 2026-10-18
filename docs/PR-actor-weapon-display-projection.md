# perf(cockpit): prepare weapon status in runtime snapshots

GameRuntime prepares the weapon display immediately before returning snapshots, including both advance return paths. Cockpit layout reads the immutable stored weapon/status strings, removing the native mesh/ray and whole-Commander readiness derivation from interactive painting. The actor updates its existing Game in place; no additional Game candidate or cache framework is introduced.

A directly constructed Game starts with an explicitly unavailable presentation. Direct/offscreen callers can prepare it before rendering; README media does so outside drawing. The projection describes the delivered snapshot and grants no emission authority. All existing native firing, resources, protection, custody and transaction checks remain.

## Validation

Authored tests check actor snapshots against current native derivation after charge progress, selection, trigger release, view/help transitions and inactive advances, and retain prior snapshot values. Existing real refused-flush/writer tests now verify that the delivered blocked status matches the refused actor state. Direct renderer coverage checks explicit preparation and consumption of the immutable projection.

Strict Swift formatting, whitespace and Markdown lint are source-only checks. No compiler, native tests, GUI, profiling or renderer jobs are run here, and no measured performance improvement or runtime acceptance is claimed. The integrator owns independent review and focused/full validation. Script, trade, custody, save formats and EMP archive persistence are outside this change.
