# Script admission exhausts the cooperative test stack

The actual full `make ci` attempt 328 at `901f75fc58412b7a6caf5d63e4010b4cf59e0f4f` failed during coverage before any complete Swift test result. Its authenticated process crash explicitly reports thread stack exhaustion in mission actor template preparation, reached through encounter admission and script event dispatch. No coverage percentage, thread/address sanitizer or leak result was produced.

The exact coverage executable (`de0102680f12b700e7d85a9d80f22053eb511e6843b26222d9b3a8e7fd1f1fa9`), all 715 compiled objects and matching process crash are preserved in `/tmp/elite-full-review-ci-328`. Disassembly shows the event drain reserves a static 28,992-byte frame and thirteen Commander reads, including finalization paths which execute only after nested admission returns. These are structural observations, not an aggregate measured stack peak.

Move the unchanged candidate finalization into a separate synchronous call after command dispatch. Preserve every admission/currentness check, receipt, acknowledgement, resource adjustment, queue and serialization limit, private publication, failure path and actor boundary. Do not increase stack limits, serialize the original concurrent test lane or introduce a new state owner. The original crashing completion test supplies the regression, with native cohort, publication rollback and choice/conversation tests checking the moved behavior.

[PR-script-event-finalization-stack.md](PR-script-event-finalization-stack.md).
