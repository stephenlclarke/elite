# Routine asset failures must not require a host restart

## Problem

M01 ship media was run through a bespoke external diagnostic wrapper. Its command-text ownership checks rejected normal process observations. A later probe also checked a newly launched child against an older in-flight snapshot. The wrapper then entered an inert hold and wrote persistent UNKNOWN custody. Its complete historical-descendant proof requirement could not be satisfied from saved snapshots, so recovery required a manual Mac restart. None of that produced ship media.

The extra asset policies, MAX1 namespaces, append-only process journals, per-command approval packets, persistent custody on routine errors and repeated orchestration acknowledgements were our operational design. They were not requested game behavior or requirements of the maintained renderer. The human explicitly directed us to fix recurrence and remove that overhead before restarting.

## Required behavior

Use the maintained `make ships` route and actual game renderer. Keep one native worker, shared execution leases, fresh resource admission, sampled owned RSS, an overall deadline, bounded cleanup, truthful failure and real output fingerprint checks. Preserve normal tests, coverage, leaks, final PR review/checks and committed-main Sonar analysis. Do not weaken those gates or run ASAN/TSAN as required CI.

A metadata error, timeout, resource failure or interrupt must attempt bounded cleanup of the child/session and return nonzero. It must not create a new diagnostic custody record, invent success, wait inertly or request a reboot as routine recovery. Partial GIFs must not be published as current by rewriting their manifest after a failed renderer.

## Historical boundary

The existing UNKNOWN586 record, consumed attempts and complete raw evidence remain unchanged. The human plans a restart after the fix. Any existing historical hold still blocks asset generation until its separately reviewed recovery is complete. This correction does not retroactively turn that attempt CLEAN or authorize a native run now.

## Limits

Process observation is sampled. Known PID/start identities survive legitimate exec and reparenting; newly visible descendants join on a later snapshot. This is ordinary command cleanup, not a sandbox or a claim to reconstruct every deliberately detached process between samples. SIGKILL cannot run Python cleanup. If the OS will not terminate or reap a process within the cleanup deadline, report its PID and a failed result for specific intervention. Do not promise all OS failures impossible or automatically require a whole-host restart. See [implementation and evidence](PR-m01-asset-execution.md).
