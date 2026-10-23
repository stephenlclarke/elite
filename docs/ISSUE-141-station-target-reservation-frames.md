# Station targeting reservation frame repair

The retained development unit run 39973423947 at c40b027e compiled in 212.52
seconds, then failed with signal 4 and zero completed methods. Its matched
normal crash report identifies image UUID 1D9221B5-507C-3926-A19B-E71524387AFD,
PID 3054, thread 0. Fault 0x16f65fff8 and SP 0x16f65fff0 lie within the actual
no-access guard 0x16f65c000-0x16f660000.

The actual path is nativePracticeReservation, recoverableMetadata,
workTargetCandidate, cycleAutoTarget, stationAutoGame and the original
NativeStationSnapshotUnitTests/originalCoverSourceStillRequiresItsOwnActualActiveHazard
method. No particular argument is attributed. This is issue 141, separately
tracked from historical unattributed issue 95.

Split the unchanged shallow body and owner eligibility checks from the full
reservation scan. Metadata requests scalar membership and ordinary actors do
not enter the owned optional-payload scan. Every eligible reservation still
requires the original instance order, actor reservation and full
NativePracticeSave validation with actual owner, engine and flight state.
State-returning consumers retain their contract. This is a bounded lifetime
repair, not a claim that all eligible scans avoid copying.

Retain all original five station-hazard arguments and assertions. Add one
meaningful membership unit using the existing real practice fixture: accept
its original allocated beacon and refuse ordinary/copy-labelled bodies,
changed retained digest and absent owning instance. The maintained unit
selection retains its previous 523 methods and adds this method (524 total).
Focused execution is pending. No broad unit, sanitizer, leak or playable M01
acceptance is claimed.

Original artifact: `/tmp/elite-mba-c40-unit39973423947`. The actual required
quality run 39973778813 separately failed stale ship media before coverage,
sanitizer and leak stages; it does not qualify or fail those later stages.

The first focused invocation at 005d3634 failed compilation after 93.218155
seconds; no test ran. ScriptInstance.digest is read-only. Correct the negative
fixture through the existing Codable replacement helper, preserving the same
corrupt-digest refusal assertion. The isolated-report fixture also advances
its exact expected method count from 523 to 524; all six report checks pass.

At source `2dab4bba6214075b1ddc5538cf3a71fc335b038f`, both focused methods
passed: all five original station-hazard arguments (9.201 seconds) and the
new authentic-versus-forged reservation unit (8.598 seconds). The complete
process exited 0 after 82.337719 seconds. Evidence:
`/tmp/elite-141-immutable-membership-units-result.json`, its raw log and complete
Swift Testing XML. This is two methods and six cases, not a full 524-method
pass. The first compile failure remains retained; issue 95 remains separate.

The normal `make ships` workflow subsequently rendered all 171 ship GIFs and
the overview from the game renderer; `make ships-check` passed for every
TOML/GIF/reference section. No renderer fingerprint or validation gate was
changed. Existing generated references were already current. Logs:
`/tmp/elite-m01-ship-media-refresh.log` and `/tmp/elite-m01-ships-check.log`.
The next coherent release head also imports only the four agreed Root-owned
workflow documents from `2c5c17458073cd3a5dfdef8206d58cda98d47fde`.
Final-head protected-main quality and the expanded 524-method gate still
require their own actual results; earlier failures are not relabelled.
