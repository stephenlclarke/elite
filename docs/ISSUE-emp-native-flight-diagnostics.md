# Identify the actual native EMP flight termination

Maintained CI 337 at `159b47322879bf09d51a661f1c1fbea3b85c4edf` recorded the original flight-continuation requirement failing in two EMPTravelAndSecurity methods (three cases). The current assertion does not distinguish death from docking or identify the frame and physical state. An independent scoop-test out-of-range SIGTRAP interrupted the full run; no complete coverage or later sanitizer/leak acceptance is claimed. Exact 716 compiled artifacts and authenticated crash are preserved in `/tmp/elite-full-review-ci-337`.

Add failure-only primitive diagnostics to the shared aiming helper. Evaluate the identical continuation Boolean once, require it to remain true, and report frame, physical time, screen, docking, energy, shields, thermal/altitude readings, speed, message and the already-captured pre-tick target range. Preserve the original 800 iterations, 0.1-second ticks, actual controls, charge, target, gear, NPCs, source, law and crew assertions. No setup or production behavior changes.

[PR handoff](PR-emp-native-flight-diagnostics.md).
