# Prepare the dead-owner fixture at a valid lifecycle boundary

After the existing fixture sets zero health and no player attribution, it now calls the real destruction resolver and requires the actor to have left the physical scene before runtime construction. The normal runtime frame still drains the queued destruction callback. All original pending-job cancellation, exactly-once notification, retained actor, commander validity and save/world consistency assertions remain.

Formatting and execution are pending. There is no production change, forced job state, fabricated impact proof, suppressed restoration error or combat-benefit claim. See [the issue](ISSUE-world-job-terminal-fixture.md).
