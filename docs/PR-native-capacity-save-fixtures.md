# test(fixtures): retain actual native capacity and save contracts

## Resulting checks

The cabin shop test derives free cargo from the actual 30-tonne SH023 hold and two five-tonne cabins, requiring a 10-tonne footprint and 20 tonnes free in both the numeric fit/profile and displayed physical-hold text. Existing equipment, crew, berth comparison and refused-purchase conservation checks remain.

The scoop test requires a genuine fitted cargo expansion, native 30-plus-15 capacity, no other cargo/passenger/mission/person payload and an actually full finite 45-tonne hold. It keeps `CARGO HOLD FULL`, retained candidate, unchanged cargo and unchanged cash checks. It then requires one body and the original cargo body ID/type before changing that body's position. Upper-scoop refusal, first lower-scoop pickup exactly once, no-scoop refusal, explicit unlimited-mode thargon pickup and the original stored/refitted scoop device/no-charge checks remain. Game capacity and scoop rules do not change.

Empty cabin storage and XYZZY display saves require the exact observed schema 26, commander scope and strict pointer/chunk reads. The cabin round trip requires the full saved Commander and original cabin ID/cash. XYZZY retains its complete existing owner/device/component/history/display/resource expectations and original station-rebind normalization; its strict disk comparison permits only the writer's documented transient NPC binding clearing. Its entire temporary directory, including save generations, is cleaned.

The missing-pack passenger test proves there are two actual purchased berths before selecting the empty one, binds the actual mission/passenger identities, and uses the whole Commander after successful first save as its reload baseline. It separately requires equality against an independent original copy with only mining policy persisted, plus original cash/cargo/name/hull/owner/equipment/history/mount/fuel/missile/contracts/full mission-calendar/accommodation conservation. Strict reading must match that saved Commander. Missing-pack load must add the exact missing-content suspension; restoring only that field for comparison must recover the entire saved Commander. The passenger and berth objects/IDs, stored empty berth and suspended contact's no-replay/no-reward property remain checked. Default load may legitimately publish its suspension into a new generation; no unchanged-pointer requirement masks that allowed change.

The timed failure test locates the actual installed pack by state ID and digest, requires the corresponding catalogue index, and verifies saved progress version/digest and exact failed stage. Its actual Gallery projection must show failure and one completed milestone before and after canonical save/load. Original payload removal, credits 1000, arrival/dock/contact without payout and rejection of an authored outgoing terminal retry remain. It does not search arbitrary names/statuses or suppress the built-in entry.

## Scope and verification

The exact parent is `159b47322879bf09d51a661f1c1fbea3b85c4edf`. Scope is six existing methods/six expanded cases in `PassengerCustodyTests.swift` (three), `DisplayOptionsTests.swift`, `MissionPackTests.swift` and `CockpitTests.swift`, plus this issue/PR pair. One nested pure identity selector is added; no new test method, production change, shared EMP helper change or adjacent correction. Frozen refs including `a7a0462`, `021c45c`, `8cec055`, `1776096`, `bfd69a2`, `f0b2331` and `1224bd0` remain preserved.

Only formatting/parsing, strict scoped lint, Markdownlint and JSON/diff/scope/hash inventory are run under this lease. No compiler, typecheck, test discovery, test, build, GUI, media, GitHub, push, merge or Sonar job runs. Root reviews the committed leaf and exact selection before G1 composes and validates it. CI 337 remains failed; source checks do not establish execution success.

Eventual PRs require completed clean `@codex review` cycles, fixes and repeat review for every actionable finding, passing required checks on the final head, required independent approval and protected merge without bypass.
