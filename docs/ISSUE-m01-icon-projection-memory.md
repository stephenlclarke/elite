# Icon rendering exceeds the local ASAN resident budget

## Observed failure

The first local 170-method ASAN cohort stopped at the owned RSS guard. The recorded sum was 2,154,446,848 bytes against a 2,147,483,648-byte budget, an excess of 6.640625 MiB. The first icon-geometry test passed after 26.648 seconds. The icon-export test then started and was still active when the guard refused. There is no complete XML or qualified shard. The second selected shard did not start, and the launch counter remains used once.

The attempt is mutable owned raw failure evidence. It is not sealed committed proof and must not be altered, resealed, imported or promoted. The recorded terminal and RSS data do not identify an allocator stack or show whether the active test was rebuilding icon geometry or drawing its first PNG. They do not establish an autorelease or cache cause.

## Source finding

The exporter calls `Display.appIcon()`, which projects the approved 99,648-face mesh through the shared shaded renderer. Each visible shaded face creates a temporary camera-space array at the caller and another inside the near-plane clipper. The icon is wholly in front of that plane: its camera-space center is 450 and its normalized radius is 115. These temporary arrays are unnecessary for that path.

The renderer also inserts every visible shaded face into a visibility set. Only the wire-detail branch reads that set. Shaded drawing returns to the next face before that consumer, so these retained entries are unnecessary too.

## Required correction

Project fully in-front shaded faces directly from the shared vertex array. Preserve the existing clipping function for other cases and keep exact vertex order, finite-output checks, face sorting, culling, material colours and wire details. Extend an existing unit method with parity assertions against the unchanged original projection implementation. Keep all original test IDs, assertions, icon exports, approved mesh, sanitizer instrumentation, diagnostics, concurrency, cohort membership and the owned budget.

The source proves these allocations are avoidable. Actual resident savings and a successful ASAN qualification remain unmeasured. See [the bounded change and validation handoff](PR-m01-icon-projection-memory.md).
