# fix(media): use bounded ordinary execution for ship assets

## Result

`make ships` now runs the maintained generator through a standard owned subprocess/session in `ship-reference.py`. It keeps single-job nonbatch Swift compilation, the existing shared controller/executor leases, RAM/disk admission, a 2.25-GiB sampled RSS limit, a two-hour overall deadline with four seconds reserved for cleanup, and a 16-MiB renderer log budget checked during and after execution. It uses the existing process-session cancellation pattern, with bounded TERM/KILL and direct-child waits.

SIGINT and SIGTERM record cancellation without interrupting cleanup; previous handlers are restored afterward. Repeated cancellation cannot skip reaping. The sampler reads only PID, parent, process group, kernel start time and RSS. It does not compare mutable argv text, demand that a future child appear in an older snapshot, or probe Swift/SDK versions before the real command. Ordinary errors return a failure after cleanup. There is no new policy/session protocol, process journal, persistent UNKNOWN writer, inert loop, automatic reboot or approval stage. Logs stay under `.build/ship-media-*/render.log`.

A failed renderer leaves the previous manifest and generated-reference publication untouched; partial media remains stale under `make ships-check`. The original group is discovered while its leader remains unreaped, before a PID can be reused for another group. Known followers remain tracked after the leader exits, with a fresh check after reaping. An unbound surviving original-group member blocks success without authorizing a PID-only signal. Forced cleanup of unexpected remaining children cannot report a successful asset run. Existing historical custody is read-only and remains respected; its old evidence and counters are preserved. The external operator wrappers are retired for routine media work and retained only as historical evidence. [Problem and requirements](ISSUE-m01-asset-execution.md).

## Validation

Twenty-six focused offline tests pass. They cover metadata/launch failure, timeout, RSS and output limits, interruption, original nonzero exit, forced/incomplete cleanup, TERM/KILL escalation and bounded reaping, PID reuse, later-discovered and reparented children, metadata-only sampling, SIGTERM during startup/running/cleanup with restored handlers, leader-exit/reparented followers, TERM-to-KILL escalation after leader reaping, late group survivors, resource admission, historical hold refusal, the real renderer command and failure before manifest publication. Child handles, queries and signals are fakes; no native process or asset generation runs in these tests. All seven existing renderer dependency tests also pass.

Native rendering and full normal coverage/leak CI remain pending until the human restart, recovery and final source review. Source tests do not establish a playable M01 release or real renderer resource fit. The change adds no Swift gameplay changes, generated-media edits, sanitizer runs or Sonar publication.

## Operational simplification and remaining limits

Use one coherent implementation review and the normal PR fix/review loop. After recovery, run `make ships` and `make ships-check`; no separate command-level policy, MAX1 issuance, review packet or Root acknowledgement is part of the asset workflow. Final protected checks and main/release gates remain required. GitHub native-runner event/head authorization remains a separate security boundary.

Cleanup follows observed owned PID/start lineage and the direct child's fresh process session. SIGKILL cannot run Python cleanup. Deliberate detachment between samples or an unresponsive kernel can also exceed this scope; a failure reports incomplete cleanup rather than silently qualifying assets or inventing a complete historical proof. The existing UNKNOWN586 is neither deleted nor rewritten by this change.
