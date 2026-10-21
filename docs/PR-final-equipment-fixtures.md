# Use owned pylons and migrate the original laser mounts before launch

## Implementation

The missile icon test starts with zero canonical rounds and grants one owned standard round into each pylon while retaining counts zero through four. It stores each actual round at the current inventory revision before unlimited mode. The final native launch uses an actual physical Cobra outside the station, matching the existing native ammunition fixture arrangement; new assertions verify successful launch, the target identity, virtual unlimited provenance and unchanged owned inventory.

The station laser test moves its original front Pulse, left Mining and right Beam mount seed before launch. New preconditions verify the actual kind and fitted slot, including the empty rear mount. All original two-tick damage, firing-rate and heat assertions remain. See [the issue](ISSUE-final-equipment-fixtures.md).

## Compatibility, validation and risk

No gameplay provider, purchase rule, authority check, original expected outcome, case selection or skip changes. A source check confirms every original expectation across all three assigned test files remains in order. Strict Swift/Markdown lint and diff checks pass. This worker has not compiled or executed the batch; focused tests and required composed `make ci` remain with the integration owner.

## Bounded six-method source follow-up

Elite combat seeds its existing military laser before launch. Elite escape/energy simulation, Blackjack mission-cargo escape, Blackjack rear-laser reload, Naval Constrictor bomb immunity and PLUGH lower-tier purchase refusal grant actual owned equipment at the original setup points. Slot preconditions verify that the intended hardware is fitted. The Blackjack reload scenario stores the actual third-pylon round using the current inventory revision and verifies two fitted rounds before its unchanged `missiles = 2` assignment; its original equipment, mounts, ammunition and mission reload assertions remain.

Original immunity, bounty, finite ammunition, cargo, credit, control/tick, no-pod refusal, purchase and reload outcomes remain. No paid prerequisites, getters or provider guards change. Reversing only deliberate setup/precondition changes reconstructs the entire five-file follow-up source exactly, including the two separately approved save-scene methods documented in [their handoff](PR-save-scene-fixtures.md). Strict lint and diff checks pass; execution remains with the integration owner.

## Fit the actual fourth PLUGH round

The exact PLUGH limits method now grants a standard owned round into pylon three before its original `missiles = 4` assignment. New preconditions verify that pylon and the four-round mirror. The original full-state purchase refusal, cash/storage/fuel checks, mount limits and higher navigation tier refusal remain unchanged. Reversing only this addition reconstructs the entire original file at checkpoint 205 source `127b32e00e233bf551247de72d5ea87d8cb8f380`. Strict lint and diff checks pass; this worker has not compiled or executed the correction. Focused 205 remains a failed 13-method run, not full CI acceptance.
