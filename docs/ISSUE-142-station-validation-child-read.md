# Station validation child-storage frame repair

The retained 524-method run 39975800481 at d04a14dd compiled in 69.51 seconds,
then failed with signal 10 and zero completed methods. Its complete matched
normal crash report identifies PID4421, image UUID
8B398BC9-8D0E-3F20-BB01-0DE5CE464EA7. Fault 0x16f7cfff8 lies within the actual
no-access guard 0x16f7cc000-0x16f7d0000. SP 0x16f7d23b0 remains above that
guard; the stack-probe frame reaches it. Do not claim that SP itself is inside.

The actual path reaches nativeStationReadScriptState, full station validation,
nativeStationBodyIsCurrent, the Commander callback, mesh/collision and station
evasion, then GameRuntime.advance in the original authenticEntryAttack unit.
This is issue142, not recurrence of issue141 or attribution of historical95.
Evidence is retained at `/tmp/elite-mba-d04-unit39975800481`.

Use typed addressable child script-state and flight reads, with default script
state construction isolated to the original absence branch. The ordinary and
approach body-current wrappers use typed stored-Commander bridges. Preserve
body identity, physical identity, world presence, complete station validation,
record, system, tombstone, energy, visit and binding checks in their original
order. Preserve all full-policy lazy/default semantics and value ownership;
no schema, authority or validation predicate is removed.

Focused qualification retains four existing methods and twelve cases:
authentic entry attack (one), in-place station mesh geometry/refusals (one),
full policy and lazy reader order (five), and storage/default/retained bytes
(five). Execution is pending. The whole524 selection, required main quality,
coverage/sanitizer/leak gates, native M01 journey and release remain separate.
The d04 signed/notarized archive and author-observed fresh docked startup
remain qualified only on their explicitly recorded scopes.

The first focused invocation at 3b8501fc failed compilation after 7.804100
seconds, before any test ran: the existing checked physical-identity reader
was fileprivate to NativeStationRuntime. Its read-only access is now internal
to the module so the relocated shared storage policy can use the same reader.
Its implementation, presence guard and all validation behavior are unchanged.
