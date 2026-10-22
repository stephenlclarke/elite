# Disclose actual retained NPC transit endpoints

Refs #18. Scripted craft with an admitted transit route can still show the local system as both origin and destination because the target panel reads only the legacy NPC route fields. The read-only adapter now uses a unique typed transit route bound to that target's mission, logical actor and current native actor, after joining the route back to the live original-world catalogue. Existing recorded or generated NPC endpoints take precedence.

The new projection checks only the needed route and phase bindings; it does not validate the whole commander or save during HUD drawing. Unsupported phases, ambiguous routes, foreign actor/visit bindings and unavailable worlds retain the existing honest fallback. Cargo continues to come directly from the current NPC manifest and provenance. Pirate/Military visibility remains unchanged; no Basic or Identification route disclosure is added.

## Validation

Four pure value methods cover spool/open/arrival route bindings, native endpoint names, tier denial, unchanged cargo/player resources, foreign actor/instance/visit, unsupported phases, ambiguity, explicit provenance, unknown versus empty manifests, live manifest changes and unavailable-world fallback. No jump, frame, native admission or fuel debit runs in these tests. The selector retains all 335 delivered base methods and adds four, for 339. All 20 Python report fixtures, Markdown lint, strict Swift formatting and whitespace checks pass; hosted Swift execution and independent final-head review remain pending. No local Swift compiler, native journey or broad validation campaign ran.

## Scope and remaining work

Only the read-only `Game.telemetryFacts(for:)` hunk, one pure projection helper, focused tests, selection and these notes change. The NPC resource simulation stays unchanged. Missing legacy cargo is still unknown. Full issue 18 shields/heat/fuel tracking, encounter persistence and delivery acceptance remain open; this PR does not close that issue.
