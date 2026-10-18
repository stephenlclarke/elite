# Integration and validation workflow

Human workflow decision recorded on 18 October 2026. Integration takes priority over documentation and coordination overhead.

Each author freezes a bounded change. One integrator independently reviews it and immediately integrates a clean change as a separate commit. An active validation snapshot stays frozen until its execution closes. Root handles risk and scope decisions; routine work within an assigned scope needs no additional approval round trip or duplicate complete review.

Batch reviewed changes into one coherent build of a clean committed head. Reuse that exact executable for focused tests. Select failed or changed paths and directly affected safety or persistence boundaries from the actual diff. Retain qualified earlier results for unchanged paths, clearly identifying their source. Avoid blanket repeats of unrelated passing suites, CLI checks or generator tests.

Run one full `make ci` per coherent integration milestone after every selected focused case passes. Coverage, thread and address sanitizers, leak checks and mandatory final-head GitHub, review and release gates remain required. A failure stays recorded and drives a bounded repair rather than a blind rerun. Preserve source and artifact fingerprints, protected user files and owned-process closure throughout validation.

Before merging any project or distribution-tap PR, request `@codex review`, wait, fix every actionable finding and repeat until clean; required checks must pass on the final head. Publish authoritative SonarQube analysis only from committed main with the exact commit SHA as `projectVersion`. This workflow grants no protection bypass or premature publication, release or completion claim.
