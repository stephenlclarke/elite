# Reject unsafe Commander input before aggregation or unbounded allocation

CR-02 identifies a startup/load crash: decoded mission payload values are summed before their bounds are validated, so two `Int.max` values overflow. CR-11 identifies unbounded file allocation: the four-MiB save limit is checked only after loading the entire file into memory.

Validate mission entry and payload bounds before aggregation, use checked arithmetic for all public cargo totals, and refuse invalid occupancy without changing the save or current game. Bound reads on the actual opened regular file, including growth after the initial size check. Keep supported large cargo and missing-pack payload data intact. See the [repair handoff](PR-save-admission-safety.md).
