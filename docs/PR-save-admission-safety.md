# Bound save input and validate cargo before publishing a Commander

Commander cargo aggregation now validates mission metadata, entry counts and payload amounts before summing. Checked totals reject overflow and invalid ordinary cargo or salvage mass. Public Int getters report invalid occupancy as full; validation uses the optional checked result and never repairs or publishes malformed data. Existing valid maximum mission and ordinary cargo quantities remain exact.

The save reader opens a nonblocking descriptor, checks that the opened object is a regular file within the existing four-MiB limit, and reads bounded chunks up to one excess-byte sentinel. Oversized, growing, nonregular and inaccessible input cannot trigger an unbounded whole-file read. Actor loading still stages the candidate and preserves file bytes, game state and input epoch on failure.

Regression source covers malformed extreme/negative mission payload rejection in a child app process, complete failed-load rollback, maximum bounded missing-pack payloads, supported maximum ordinary cargo, exact-limit data, oversized sparse files, directories, device input and FIFOs. The app's validation-only command returns a controlled failure without opening a game window or logging Commander contents.

This repair is source-only and unexecuted. Formatting, syntax and documentation checks are required before the isolated validation lease; no prior 026 pass applies to the changed runtime. CR-01, effective component admission and economic scoring are separate repair slices. Motivation: [issue handoff](ISSUE-save-admission-safety.md).
