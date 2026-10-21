# Separate physical cabins from passenger places

FR-058 requires every cabin to consume 5t, from a densely packed twenty-person cryogenic cargo module to a one- or two-person stateroom with long-journey stasis. Intermediate grades trade capacity for comfort. The existing model assigns one physical five-tonne module to each PassengerBerth, so multiplying its person count would either charge mass twenty times or lose individual custody and private-cabin promises.

Keep a distinct physical module and a fixed set of individually identified passenger places. Preserve unique script/native person identity, mission reservations, working life support, stasis condition, explicit transport-mode consent and existing atomic durable actor transactions. Existing native journeys still require separate awake cabins. Initial intermediate counts/prices are project balance choices, not human-prescribed values.

## Implementation

Add the six explicit storefront layouts and physical OwnedPassengerCabin records. PassengerBerth remains one uniquely identified place with a parent cabin and ordinal. Charge 5t and one equipment unit per fitted module. Store/refit only whole empty modules; preserve all identities across compatible hull transfers. Update equipment, query, display, current-save and native reservation/consent consumers together. Bounded, exact-shape decoding rejects invalid layouts, identities and custody. Historical native offers retain immutable grade/layout facts after genuine hull loss, without depending on cabins that were lost with the hull. Update only the now-false generated ship basis wording from its maintained generator.

## Validation

Authoring is isolated on the MBA, where native execution is unavailable. Swift formatting, strict lint and static scope/data checks are performed before freeze. Focused runtime/unit selectors are listed in the paired PR note. Compilation and actual owner execution remain pending G1 after M01 publication; no source/style result is a native PASS. One complete independent review follows focused owner PASS. No compatibility decoder, save migration, new mission or equipment framework is introduced.

## Compiler-only correction

Actual matching builds 1269 and 1271 reject borrowed Commander capture in NativeOriginalRescueJourney.replyToTransportOffer: first through Optional.map, then through the && autoclosure even after extracting a borrowing helper. No tests ran on either rejected build. Original raw evidence remains at /tmp/elite-FR058-cabin-build-1269/build.log (SHA256 8707838e33dc7c4f7f4defc90b1c4ffebd8669b43e13ae6839e871822a1e5ac0) and /tmp/elite-FR058-cabin-compiler-build-1271/build.log (SHA256 43a5b463f9b05a931bfd2048d14da8c0cc5f8004e97b4a0dc4f958df8cdef61a).

The combined child stages the same predicate inside the existing reply function. Destination/path/count and optional place life-support/compatibility checks run first. Only when that prefix succeeds does a direct support call read borrowing Commander outside any autoclosure. Private-cabin status, reservation and offered-place suffix checks follow in the original short-circuit order. Nil remains ineligible, and the original optional berth is retained in the reply. The now-unused helper is removed. No owned Commander copy, moved predicate evaluation, state/storage/schema/authority change or test selection change is introduced.

Parent 6694b3821a04b069ce2b2c6617da3e16ef4e883d and the first compiler child 8700cad004f239e5f5cf3eaddccbdf36b4663ee5 remain immutable. Whole-source inverse and the other 205 parent feature blobs are verified. Source checks do not establish compiler success. G1 owns a fresh matching compilation, then the unchanged primary 11-method/12-case cohort before remaining focused qualification and full independent review.

### Test macro correction

Actual matching build 1273 no longer reports the borrowed rescue-code error. It fails only at the mutating showScriptDialogue call inside require in PassengerCabinGradesTests: the macro projects an immutable receiver. Raw evidence remains at /tmp/elite-FR058-cabin-staged-build-1273/build.log, SHA256 46cc4f263a05f4c754226ad1945267442e77b5f5401cb73b45c270e3c1047029. No tests ran.

Evaluate that same one dialogue call into a local Boolean immediately before requiring its result. The action order, assertion and oracle are identical; production code and all other tests remain unchanged. Parent 70307c6007225fb16b40c8d7e2f306170964fa42 is immutable. A fresh G1 matching compilation and the unchanged primary 11-method/12-case selection remain required; source checks are not native PASS.
