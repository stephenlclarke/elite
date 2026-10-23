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
