# Native debris impacts need station translation and real resources

## Motivation

The reviewed debris contact core refuses station contacts because an anchored station has no authority to retain equal-and-opposite momentum. Silently discarding the station impulse would create an invisible momentum sink. NativeStationSavedPose and the original main anchor are immutable authored source geometry; changing those values would break source identity and cannot represent physical motion.

## Required behavior

A genuine native contact must retain finite station momentum and displacement independently of source geometry, apply damage to actual original or RRS resources, and derive current bodies, doorway checks, save validation and departure from that motion. A moved station remains a physical hazard after the original debris leaves. Unproved paths, stale identities or inconsistent current poses must refuse without inventing arrival, destruction or mission rewards.

## Scope and acceptance

This source slice covers native original-main/RRS translation, current resource authority, current-format persistence, projection and existing entry/exit consumers. It adds no stored Game fields, whole-Game snapshot, world-generation change, market change or mission-state shortcut. Angular impulse and mission-profiled inertia remain outside this leaf.

Acceptance requires central execution of genuine generated-debris contacts against main and RRS hulls, equal-and-opposite momentum and resource effects, retained source identity, coast, current roundtrip, native readmission/relaunch and malformed-state refusal. The required make ci, sanitizer/leak/coverage gates and full debris/campaign acceptance remain central-owner work. Source formatting alone is not runtime acceptance.

## Related work

See ISSUE-asteroid-swept-impacts.md, PR-asteroid-swept-impacts.md and PR-native-station-inertia.md. No GitHub issue or PR has been created for this leaf.
