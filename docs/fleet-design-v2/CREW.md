# Minimum operating crew and station recruitment

This is a new bounded design decision needed to make per-hull crew requirements real. It is not a claim that the current game already has a complete recruitment service. Root assigns this prerequisite within track A before multi-person requirements are activated. It does not add a crew combat-stat, skill tree, wage clock or new keyboard binding.

## Required state

Each hired person has a stable actual person identity, consent to a crew contract, assigned ship identity and an intrinsic crew place. The commander counts once. Passenger, rescued, detained, mission-reserved and stasis-only people cannot automatically count as working crew. Use the current native person/custody model and serialisation; do not introduce a parallel integer-only population or copy a person between ships.

The minimum counts in the ship TOMLs are new general operating complements including the commander, not per-job skill requirements. Additional specialist skills are out of scope. Intrinsic places equal the proposed complement; a family owner can revise that estimate only with a recorded physical-layout reason, never by importing an unrelated old SH-ID profile.

## Recruitment transaction

At an actual docked station, the existing station-person roster supplies consenting, unreserved adults who are eligible for crew service. It must be a finite native source with stable IDs. If no compatible real person is available, show that condition and offer no hire; a visit, reload, quote or decline must not respawn or replenish a roster. Any replenishment must follow the existing population/arrival authority.

Use a contextual **Crew** action within the existing station equipment/ship service area. The player selects people with arrows and confirms with Return; Escape cancels. Each recruited operating person costs **200CR once** as a new design balance choice. This pack adds no recurring wage. Show actual names, open intrinsic places, assigned count, minimum requirement and the total before confirming. Do not auto-hire as a hidden side effect of buying a hull.

On Confirm, atomically debit the exact quote, remove the same consenting person from station availability and assign the same identity to the ship/place. Reject stale roster, wrong visit, occupied place, insufficient cash, changed ship or lost consent without partial mutation. Under-crewed ships may be bought and retained docked, but normal launch is refused with the actual missing count and the Crew action. An under-crewed mission/ambient NPC must follow its own explicit autonomous or emergency policy; the player gate is not a global rule that freezes unrelated actors.

## Exchange and disembarkation

Keep crew on the same ship until the exchange transaction transfers them into actual free intrinsic places on the new owned hull. If the new hull has fewer places, present explicit voluntary disembarkation at the actual station before confirming sale. Retain the same people in its native roster; do not sell, delete or silently dismiss them. Disembarkation has no refund and does not clone recruitment eligibility. A cancelled trade changes nothing.

Saving/loading preserves assignments, actual locations, consent and all once-only cash transactions. Destruction/escape uses the existing actual crew survival/capture/death lifecycle. Do not automatically rescue operating crew, award mission transport progress or count them again as passengers. Tithe native conversions and the native Larvaal Drone can have zero crew; safe player conversions use the explicit crewed layout and normal requirements.

## Focused acceptance

Demonstrate one genuine station-person hire and reload, stale quote refusal, insufficient cash rollback, duplicate-person refusal, occupied-place refusal, passenger/mission-reserved refusal, same-person disembarkation, and exchange to a smaller hull. Confirm that the starter SH025 remains operable by its one commander and that the game reports the real missing complement for a larger hull. These are implementation requirements, not executed results from this design task.

The researcher's Medusa service loan is an explicit exception to a paid recruitment prerequisite: its real compatible hull, required consenting crew and tools must be supplied without fee/deposit or a solvency/rank gate. Preserve the player's own people and equipment in actual storage/custody; do not use the exception to fabricate crew identities or grant a permanent ship. See [the controlling salvage alignment](SALVAGE-ALIGNMENT.md).
