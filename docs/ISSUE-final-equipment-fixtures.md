# Missile and laser fixtures must configure actual fitted equipment

## Observed failures and cause

Full CI checkpoint 202 on `1c187ac2f70bfd634cf7913d19b5867f07bf5bb3` reported the missile icon test failing to become unarmed after firing and eight mount damage/heat assertions in the station test. Post-launch scalar ammunition and legacy laser-mount mutations do not configure the canonical owned fittings used by native consumption and damage. The icon fixture also needs an actual admissible launch scene for its final unlimited discharge.

## Required correction

Seed the original four-mount layout before launch migration and verify each actual fitted slot. Build missile counts zero through four using actual owned pylon grants, then store those rounds before the zero-round unlimited case. Fire into a physical target in the existing native-ammunition fixture arrangement, requiring actual launch and virtual ammunition provenance.

## Validation and limits

All original icon/text, mount damage/rate/heat and empty-view assertions remain in order. Static source/Markdown lint and diff checks pass. No execution occurred in this worker; the integration owner retains focused execution and full `make ci`. Checkpoint 202 remains failed evidence. See [the implementation](PR-final-equipment-fixtures.md).
