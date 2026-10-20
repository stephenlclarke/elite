# ci: retain attributable native images and crash reports after quality failure

## Problem and behavior

The existing wrapper retains raw make ci output and PID/start-owned process history, but its artifacts omit the actual hosted test image and symbols. Failure collection now reads only already-observed SwiftPM helper arguments and associates symbols only through an actually observed dsymutil input/output. It copies confined native test images and UUID/architecture-matching dSYMs into the existing reports artifact, with exact bytes/hashes/source/process provenance. No toolchain/system binary is copied. The512MiB shared retention cap refuses whole files/bundles explicitly instead of truncating them; missing or unsafe symbols do not discard a retained valid test image.

The fixed two DiagnosticReports roots now expose availability/access errors and .ips/.crash format counts, candidate hash/mtime/size and elapsed collection facts. Modern multi-document IPS and strict legacy PID/Path/Launch Time identities must join an actually observed owned PID/start/executable before raw bytes are retained. Missing launch, malformed, changed-during-read, unrelated or escaping candidates retain bounded metadata/refusal only. The existing3.5second drain remains; absence or success is not a reporter configuration or crash-cause claim.

## Implementation and ownership

A small stdlib-only Tools/CI/crash_artifacts.py isolates filesystem/identity work from the existing hosted-only wrapper. Tools/CI/test_crash_artifacts.py imports only that module, never the wrapper or make/app/native tests. Makefile ci-capture-check runs its focused tests as a normal ci prerequisite; workflow uploads remain unchanged. Existing make ci, raw exit status, before/after source checks, owned-process cleanup and execution/stack/concurrency/sanitizer behavior remain authoritative. Capture errors are recorded without replacing the original failing make status.

## Focused validation

Owner make ci-capture-check passes twenty unit methods using temporary synthetic file/report/UUID-output fixtures, no actual native executable or test invocation. They cover observed helper selection versus compiler filename mentions, confined paths and binary/dSYM/report symlink escapes, UUID mismatch/tool failure/missing symbols, size-cap priority/refusal, byte/hash/source/process manifests, modern and legacy owned reports, unrelated/PID-reused/missing-launch/malformed candidates, absent/unreadable roots and unchanged baseline exclusion. All three Python sources parse; the hosted wrapper is not imported or executed. Scoped Markdown lint and diff checks accompany freeze.

One independent whole-slice bugs/performance/style/security review remains pending. Unit fixtures do not establish real hosted crash capture or fix the production SIGBUS. The actual43/399 failures remain preserved, and missing raw reports still mean no proven stack/site. Integrate only after review; combine one maintained renderer refresh with the next necessary qualified PR checkpoint because Makefile participates in conservative freshness. No diagnostic-only CI rerun, unrelated README-media generation, image fingerprint weakening, protection waiver, merge or release. See [motivation and bounds](ISSUE-hosted-crash-artifacts.md).

## Independent review corrections

The one complete six-path review found two P2 artifact-budget issues. Retention now makes a global first pass over all observed images before any earlier cohort can spend the shared cap on symbols. Report collection rechecks current file size, bounds reads to the remaining allowance plus one sentinel byte, and checks the actual bytes read before retention, rather than trusting a stale directory snapshot size. New meaningful fixtures cover a later cohort image competing with earlier symbols, report growth between stat/hash and report growth during the actual read; each rejects over-cap originals without truncation. The full review and original frozen8c497 source are retained. Twenty focused owner unit methods pass; this delta returns to the same reviewer, not a second full review.
