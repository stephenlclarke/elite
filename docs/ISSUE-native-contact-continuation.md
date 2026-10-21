# Native contact continuation

## Problem and behavior

A real debris collision could reject the rest of its movement because a fresh containment query discarded a previously certified clear frontier, a contact inside the first bounded leaf returned a zero lower time, or repeated impulses against different material faces exhausted the pair budget. Thin edges could also cross between samples without either vertex entering a triangle face.

The native sweep carries a transient single-use proof bound to immutable prepared geometry and exact certified lower poses. Continuation explicitly proves a positive clear prefix before searching the remaining interval. Fresh queries retain the original containment rules. Fixed orientations and equal acceleration permit outward interval triangle separation and a Cramer-rule edge/edge crossing certificate. Every original triangle remains authoritative; unresolved geometry, unsupported motion, contradictory witnesses and exhausted budgets still refuse.

Nonstation collisions stage chronological responses in a value candidate. Each response resweeps the entire scene using the existing shared 32-pair limit. Another pair's contact, uncertain separation, stale geometry, nonprogress or capacity exhaustion rolls back the step. Living victims receive effects at actual contact poses. Further mechanical responses after death preserve momentum without repeating health, death or reward settlement. Station transfers retain their existing transaction.

## Conservation and compatibility

A single material face retains restitution 0.15. Multiple certified faces are resolved together by projecting relative velocity onto their nonclosing cone. Restitution is capped at 0.15 and reduced where necessary to avoid rebounding into an earlier face. Equal and opposite impulses preserve total linear momentum; kinetic-energy loss determines damage. Authored masses, hulls, duration and work budgets are unchanged.

The proof and response plan are private transient state. There is no save-schema change, decoded authority, public bypass, tolerance increase or geometry substitution. Original tests and their physical oracles remain intact. The separate current-release fixture corrections accompany this packet and retain their documented compatibility scope.

## Focused verification

G1 compiled the current source and ran five isolated geometry/impulse unit methods on 21 October 2026. All five passed: positive frontier progress within the first leaf; two-face nonclosing response with momentum and energy conservation; three-face restitution and momentum; scalar impulse conservation; and edge-only contact between crossed thin bars. The retained log is `/tmp/elite-m01-isolated-physics-1325.log`. These methods exercise in-memory geometry and pure impact policy, without a Game or GameRuntime journey.

The earlier 1320 broad run completed 120 methods/340 cases, with 114 methods/333 cases passing and six methods containing seven cases failing. That failure record remains historical. Subsequent development identified the positive-prefix, corner-response and edge-certificate causes above. The earlier broad result is not converted into a pass, and the new five-unit result does not qualify the whole M01 milestone or a playable release.

Current human direction prohibits integration testing during code completion. No broad CI, full game/mission journey, GUI, performance, sanitizer, leak or release acceptance is claimed for this packet. MBA independently reviews the pushed diff and runs the five isolated units; actionable findings become GitHub issues. Development continues while that review is pending. Required final-head checks and the repeated clean `@codex review` policy still apply before any PR merge.
