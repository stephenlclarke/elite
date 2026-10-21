# Add the Capital parent and typed Station subtype

Adds optional typed `capitalSubtype = vessel | station` alongside the existing Capital parent flag. The technical `objectKind` remains unchanged: active PLUGH stays a platform adaptation and SH161 remains a station/carrier. Structural hierarchy is independent of the eight displayed types and seven functional AI roles.

Only ten per-hull hierarchy records change: SH043/SH081/SH123 remain Capital/Vessel, and SH028/SH034/SH102/SH141/SH156/SH161/SH164 become Capital/Station. No other metadata capability or source-body value changes. Stations retain docking completion, activeStationIndestructible and never-purchase; vessel capitals retain destruction completion. Large civilian haulers are not reclassified from their size, cargo or names. Liberator retains its explicit Alien/XYZZY-only exception.

The pure validator replaces the former ship-only Capital guard and rejects a missing/contradictory subtype or a station destruction override. The shared maintained input/writer and reference generator carry the hierarchy; generated media/reference execution stays with G1. The catalogue remains171 IDs and168 normal collection members, each appearing once rather than once per hierarchy level.

Targeted source tests cover the exact parent/subtype roster, unchanged station technical kinds and policies, unique membership, eight display types, large civilian purchases and malformed parent/subtype/milestone combinations. Local checks are formatting, Markdown/Python syntax and exact source/data preservation; no compiler, tests, native/runtime or media jobs ran here.

This is hierarchy only. Actual receipts, damage enforcement, counters and provider reachability remain G1-owned. FR053 drug-factory admission/guards/salvage and the real SH164 port remain separately queued; an abandoned wreck is not made into a live station by a catalogue parent.
