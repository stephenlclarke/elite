# Preserve actual hosted native crash evidence

## Actual evidence gap

Hosted43a72042 and39943f45 pass actual Swift6.1.2 production/test compilation, then terminate coverage runtime with SIGBUS10 without a final run summary or retained crash original. Both eight-file artifact sets preserve actual owned SwiftPM helper PID/start/arguments and observed dsymutil output paths, but no test Mach-O, dSYM, UUID or core. No adjacent interleaved test name identifies the crash site.

The current collector copies only new/changed flat .ips reports from two fixed DiagnosticReports directories for about3.5seconds. Empty crash-originals cannot distinguish unavailable directories, another report format or no produced report. The source and artifacts do not establish that CrashReporter is disabled or that the collection delay caused the absence.

## Authorized slice and acceptance

G1 owns only Tools/CI/capture-quality.py, its new small stdlib artifact module and fixture tests, a Makefile ci-capture-check prerequisite and these paired notes. Retain actual already-owned helper-argument test images under the current workspace build tree, matching symbols from an actually observed dsymutil producer, native UUID/hash/source/PID-start provenance, and strictly attributable raw .ips/.crash originals. Explicitly audit fixed directory availability/formats/window/refusals. Reject filesystem/symlink escape and unrelated report content; do not copy toolchain binaries or broad build directories. Bound retained originals to512MiB without truncation, prioritizing the actual test image.

Preserve the original make ci invocation/status, process ownership, source integrity, execution/stack/concurrency/sanitizer budgets and3.5second report drain. No reporter configuration, backtrace flag, debugger, production change, diagnostic-only CI rerun or invented local substitute. Meaningful synthetic filesystem/report/UUID-output unit tests and one independent full-slice review precede integration. Actual hosted capture qualification waits for the next necessary corrected candidate; one maintained ship-media refresh is required at the combined Makefile checkpoint. Companion: [PR-hosted-crash-artifacts.md](PR-hosted-crash-artifacts.md).
