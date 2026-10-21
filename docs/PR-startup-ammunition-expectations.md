# Cover finite ammunition in startup migration

The shared startup assertion helper now verifies version-two physical ammunition alongside the four standard foundations. It checks the unchanged legacy count, matching round IDs in legacy entitlement records, their owner/node/provenance, and exactly the expected occupied pylon slots. The original test bodies, remaining full-JSON comparison and startup file/rollback behavior are unchanged.

Formatting and runtime validation are pending. No production code, decoder, accepted save bounds, inventory policy or migration behavior changes. See [the issue](ISSUE-startup-ammunition-expectations.md).
