# refactor(stations): separate known-world condition persistence

`persistNativeStationConditions` keeps its exact system query, optional-world guard and conservative nil-world body refusal. Once the world exists, it calls a private known-world phase with the same local passed by `inout`. That phase contains the entire original remainder without changes. See [the failure and scope](ISSUE-native-condition-save-phase.md).

## Preservation

Inlining the helper reconstructs the complete previous `NativeStationRuntime.swift` exactly. Main-station resource updates, every native body/identity/binding/energy/tombstone check, condition changes, final validation and Commander assignment retain their original order and contents. No second world local, new save candidate, weakened guard, input normalization, test change, stack setting or boxed Game state is introduced. The required atomic candidate in native save preparation remains untouched.

## Evidence and validation

The exact old default-coverage method audit identified zero Game stack slots/copies, a 4,864-byte fixed frame plus 48 bytes and one world slot before the guard. These are old-object facts, not measured new-frame reduction, total stack peak or runtime acceptance.

The original `campaignGalleryFailedRetryConsumesItsPaintedAttemptEvenIfTheFaultRepeats` failed alone at checkpoint 185 on unchanged source `0a4db147a3e9e44805deaac241fbc04a2f317183`, signal 10, raw log SHA256 `aa67231033083ae9c87b08e82ab6d0a3db4a2bd2daf77942a5fad5eb327fbaad`. Protected inputs and process closure were verified. Checkpoint 184's actual stopped thread identifies the nil-world body-check path; no matching original OS report establishes the cause of 183 or equivalence to earlier TSan failures.

Strict Swift source lint, Markdown lint, whole-file inlining and whitespace checks pass. The new phase is uncompiled and unexecuted. Actual compiled shape, the original failed method, native station/save regressions and final composed `make ci` remain required. The Core change also requires renderer fingerprint regeneration through the actual game before release. External review, final-head checks and protected merge remain separate gates.
