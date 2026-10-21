# Settle a terminal actor before runtime restoration checks

The dead-owner world-job regression directly supplies a zero-health body, then constructs a runtime with an unsettled retained actor still marked present. The runtime's preflight correctly refuses that inconsistent scene before the first tick; the expected destruction and job cancellation therefore never occur.

Run the existing terminal condition through the actual destruction/removal boundary before runtime construction. Keep the actor's ordinary deferred destruction event for the real frame consumer to drain and preserve all cancellation, once-only callback, saved-world consistency and reload assertions. This remains a terminal-condition fixture; it does not simulate or claim a weapon hit or player kill.

See [the implementation](PR-world-job-terminal-fixture.md). Production restoration guards must remain intact.
