# Gameplay fixtures still mutate legacy equipment after fitting

## Observed problem

Full CI checkpoint 195 on `73ca30b5daba33b539e20d027cfd494356013036` failed. The assigned failures cover Constrictor damage and debrief, energy upgrades, Galactic Hyperdrive travel, bomb kill attribution, targeting disclosure downgrade and showroom shaded geometry. Other failures and the crash remain with the integration owner.

## Cause and required correction

After launch prepares canonical equipment, changing the legacy equipment names does not change actual fitted hardware. Configure the military laser and energy upgrades before launch, grant actual owned bomb and Galactic Hyperdrive devices at their original setup points, and store the fitted targeting core before fitting Basic for the disclosure downgrade. Verify the actual fitted hardware before exercising each scenario.

Ray Mk I and Military Stingray render textured triangles rather than flat panels. The showroom must use the existing clipped ship-surface query to recognise their shaded geometry while retaining the wire, surrogate and rotation checks.

## Compatibility and validation

This is a test-fixture correction. All original outcomes, counters, credits, inventory identity/history and gameplay sequences remain; production code is unchanged. Strict Swift formatting and diff checks pass. Compilation, execution and the combined `make ci` remain with the integration owner. No full-suite pass or crash resolution is claimed. See [the change details](PR-final-gameplay-fixtures.md).
