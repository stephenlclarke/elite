# Nil-world station-condition persistence retains known-world frame storage

The composed coverage run at checkpoint 183 failed with signal 10 before any method completed. Its exact default coverage binary then stopped under the debugger at checkpoint 184 in the original Gallery failed-retry path, through native save preparation and destruction resolution to the nil-world branch of `persistNativeStationConditions`, at its conservative body check. No matching original 183 OS report establishes equivalence.

## Actual evidence and required repair

The exact-object audit found no Game stack slot or copy in this method. Game metadata access supplied field offsets. It identified a 4,864-byte fixed frame plus 48 bytes and one required world slot allocated before the optional-world guard. Required atomic save candidates must remain unchanged.

Keep the public system-identity query and optional-world guard in their original order. Preserve the nil-world check that throws when any native station body lacks a world. After a world exists, pass that same local by `inout` to a private phase containing the complete old remainder: world validation, main-station resources, native body/binding/tombstone checks, condition updates, final validation and Commander publication.

## Acceptance and limits

Inlining the private phase must reconstruct the whole old file exactly. Do not add a second world local, skip any guard, change authority, box Game state, increase stacks or alter the original tests. Strict source lint and whitespace checks precede actual compiled frame inspection, the original failed Gallery method, related station/save cases and the full maintained gate. See [the implementation handoff](PR-native-condition-save-phase.md).
