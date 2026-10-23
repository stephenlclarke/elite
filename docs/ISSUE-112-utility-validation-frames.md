# Rescue acceptance reaches an eager utility-validation frame

The current two-method/seven-case check atba83e0d2 exited signal10 after12.580s,
with zero completed methods and unfinished XML. The existing bcd75 binary has
an identical source tree and UUID47C6753F-4A04-3844-AD3F-FCF13F2930DC.

The owned diagnostic selected PID7964/thread10, fault0x16fe03fa8 and
SP0x16fe03f80 inside the no-access guard0x16fe00000-0x16fe04000. Its actual
caller chain enters UtilityPack.marked, UtilitySave/CrewLogSave, Commander
validation and rescue-accept event validation. Other stopped threads do not
identify the fault. The demangler top frame implies no utility semantic defect.
Retained original result: `/tmp/elite-112-rescue-units-result.json`; diagnostic:
`/tmp/elite-112-ba83-diagnostic`. Diagnostic exit0 is not a test pass.

The4334da19 changed-source run compiled75.39seconds then exited signal10 after
90.005seconds, with no completions. Its selected fault moved to the parent
crew-log receipt closure: NativeCrewLogCapture metadata, parentClaimsValid,
Commander/event validation and actual rescue acceptance in the writer-refusal
method. UUID1E03F81D-24C7-3509-B1C3-268EF67F6E23/PID16093, fault0x17051ffd0
and SP0x17051ffb0 lie in guard0x17051c000-0x170520000. Retained capture:
`/tmp/elite-112-4334-diagnostic`. This is current-image attribution, not an
assumed recurrence of the earlier utility marker frame.

Atd2d31c1a, compilation86.77seconds passed and the original check exited
signal10 after100.325seconds, zero completions. Its actual selected thread14
(PID22584/UUIDA8BDD177-0B96-33D8-841B-124059C95F42) enters ArkSave.arkClaimsValid
through Commander/event/rescue acceptance. Fault0x170637fa0 and SP0x170637f80
lie in guard0x170634000-0x170638000. Capture:
`/tmp/elite-112-d2d3-diagnostic`; no previous-frame recurrence is assumed.

Source and static emitted-code inspection of this same path also identify a
whole Commander copy in validateScriptEventCommander before the policy walk:
metadata/dynamic stack allocation and CommanderVWOc at0x731d674. The existing
safe-read callback still emitted a copy, so merely renaming a borrow would not
address it. Static records: `/tmp/elite-112-validateScriptEventCommander-prologue.txt`
and `/tmp/elite-112-arkClaimsValid-prologue.txt`.

At6a2b2071 the genuine classifier completed PASS10.407s; the overall check still
failed signal10 after137.915s (compile122.59s), with writer cases unfinished.
Writer-only capture selected PID34918/thread13, imageUUID3064B510-1337-374E-8982-86B9445F8A39,
fault0x1705abf30/SP0x1705abf10 in guard0x1705a8000-0x1705ac000. Its actual
path is care transfer through transferredNativePeopleCommanderIsValid and the
generic withReadOnlyCommander copy, then full custody/admission validation.
No admission semantic defect is inferred from the top state metadata. Retained
capture: `/tmp/elite-112-6a2b-writer-diagnostic`; no diagnostic pass is claimed.

The original acceptance/classifier criterion is qualified by its6a2b2071 pass;
issue112 is closed on that exact scope. The remaining six-stage writer failure
is tracked separately in [issue140](https://github.com/stephenlclarke/elite/issues/140).
Atb464854e compilation67.15s passed, but writer cases exited signal10 after
83.661s with unfinished XML. The current writer-only capture selected
PID41568/thread10, UUIDEB0EF062-7899-3A62-A06D-A756B472EB2A,
fault0x170493ff0/SP0x170493fa0 in guard0x170490000-0x170494000. Its actual
boarding path reaches passengerFit/performance before boardOriginalRescue's
future mutation temporaries are used. No hull, hashing or capacity semantic
fault is inferred. Capture: `/tmp/elite-112-b464-writer-diagnostic`.

Theb8ff47aa first boarding split failed compilation after18.367seconds, before
any test ran: Swift requires owned optional values for the header's binding
and reservation phase's forced member projection. Keep the common readonly
borrow, and make each required copy explicit inside its own header/reservation
leaf. Those temporaries remain outside the capacity phase's common frame.
