# Separate physical cabins from passenger places

FR-058 requires every cabin to consume 5t, from a densely packed twenty-person cryogenic cargo module to a one- or two-person stateroom with long-journey stasis. Intermediate grades trade capacity for comfort. The existing model assigns one physical five-tonne module to each PassengerBerth, so multiplying its person count would either charge mass twenty times or lose individual custody and private-cabin promises.

Keep a distinct physical module and a fixed set of individually identified passenger places. Preserve unique script/native person identity, mission reservations, working life support, stasis condition, explicit transport-mode consent and existing atomic durable actor transactions. Existing native journeys still require separate awake cabins. Initial intermediate counts/prices are project balance choices, not human-prescribed values.

## Implementation

Add the six explicit storefront layouts and physical OwnedPassengerCabin records. PassengerBerth remains one uniquely identified place with a parent cabin and ordinal. Charge 5t and one equipment unit per fitted module. Store/refit only whole empty modules; preserve all identities across compatible hull transfers. Update equipment, query, display, current-save and native reservation/consent consumers together. Bounded, exact-shape decoding rejects invalid layouts, identities and custody. Historical native offers retain immutable grade/layout facts after genuine hull loss, without depending on cabins that were lost with the hull. Update only the now-false generated ship basis wording from its maintained generator.

## Validation

Authoring is isolated on the MBA, where native execution is unavailable. Swift formatting, strict lint and static scope/data checks are performed before freeze. Focused runtime/unit selectors are listed in the paired PR note. Compilation and actual owner execution remain pending G1 after M01 publication; no source/style result is a native PASS. One complete independent review follows focused owner PASS. No compatibility decoder, save migration, new mission or equipment framework is introduced.
