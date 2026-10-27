# Audit writer fixture first-publication precondition

Run39980120332 at e2f0498c separately reported Cocoa260/missing commander.json
from NativeC01ReservationAuditUnitTests/refusedWriterRollsBackAuditAndAcknowledgementThenFreshRetryCommitsOnce.
The method declaration is the reported location; the raw report does not give
a throw line. The same run has a distinct unattributed Kite decoder crash
tracked in issue144; do not treat these observations as one cause.

The fixture registers a destination, which explicitly does not publish a file.
Its controlled heldAtSorel setup does not guarantee an initial saved pointer.
The writer-refusal test nevertheless reads prior pointer bytes. Publish through
the real runtime.save(to:) before taking the baseline snapshot, review and
pointer bytes. Keep the directory block, actual refusal, whole-state rollback,
absent audit and fresh retry/payment assertions unchanged. No production save,
registration or validation policy changes.

This is issue145. Retained evidence:
`/tmp/elite-mba-e2-unit39980120332`. The original e2 aggregate remains failed,
with zero completed methods and unfinished XML; no full524 qualification is
claimed. Focused execution of the unchanged writer-refusal method is pending.

At source6355088e395d7fd1a4c1cdacbaba83f4bcf0638a the original writer test
passed with complete XML and zero failures/errors/skips. Compilation48.51s,
method9.562963s, total process63.792762s, exit0. Evidence:
`/tmp/elite-145-initial-pointer-units-result.json`, raw log and Swift Testing
XML. Independent source/result review closed issue145 on that criterion.
This does not establish the cause of the separate SIGILL or qualify full524.
