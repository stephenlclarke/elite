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
