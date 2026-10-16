# Preserve mission catalog, equipment and trading invariants

The 16 October 2026 coding review identified five related defects in the current central app: CR-03, CR-04, CR-08, CR-12 and CR-13. They concern the existing schema-1 mission runtime and canonical equipment inventory. The accepted schema-2 Mission engine remains a separate integration dependency.

Replacing an installed catalog can leave the open Gallery selection outside the new list. The installer also accepts a 65th external pack even though the next reload rejects directories above 64 files. Identical reinstall under a different filename can create a duplicate on disk, and a new pack's default filename can collide with an unrelated installed pack. Installation must preserve a reloadable directory and publish catalog changes only after the write succeeds.

Mission hardware actions publish a new Commander without adjusting live energy or shields to changed capacities. Delivering the bundled Thargoid Plans after a recovered energy-capacity upgrade on the outgoing Extra Energy Unit can leave energy above the replacement unit's maximum. The correction must preserve charge fractions and rollback, with no new whole-Game snapshot on this stack-sensitive path.

Route sale estimates value the marked Blackjack firearm even though actual trading correctly reserves it. Profit calculations also multiply admitted extreme cargo quantities by ordinary price differences in Int, which can overflow. Custody-aware estimates and safe signed accumulation must preserve ordinary economics, cancellation, deterministic ranking and the existing public result shape.

Acceptance requires regressions for catalog reorder/shrink and safe empty access; 64-pack installation, identical reinstall, rejected overflow/collision and reload; real upgraded hardware with partial/full charge and rollback; marked-only and mixed cargo; and exact integer boundaries, signed cancellation and unsaturated ranking. See the [implementation and validation handoff](PR-mission-economy-review.md). Execution and integrated acceptance remain pending.
