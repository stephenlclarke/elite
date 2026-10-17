# Fit actual targeting hardware in the existing fixtures

## Change

The common `computerGame` and `lockedGame` fixtures, and the textured-hull visibility fixture, now configure their existing legacy core before launch. The ordinary launch migration creates the actual fitted canonical core. New setup preconditions verify the requested tier; `lockedGame` also verifies its real AUTO and weapons locks before any destruction scenario.

The station-guidance test still launches without hardware and checks the original `FIT A TARGETING COMPUTER` refusal. It then uses the existing explicit fixture grant at `.targetingCore` with fixture provenance, verifies Military is actually fitted, and performs its original sequence. The test is throwing so a real fitting failure cannot be ignored. See [the observed failures and cause](ISSUE-targeting-fixture-canonical-fit.md).

## Preservation

All original status/identity disclosure, kill attribution, target loss, manual cancellation, C/R/P/Q/chart inputs, movement ticks, final docking, viewport clipping and three display-style assertions remain. The initial no-core negative stays before the explicit grant. No production getter, installer, inventory validation, entitlement, purchase or allocation logic changes. The five previously authored texture/export cases remain the same cases; this repair strengthens their actual-core setup.

## Validation

Strict Swift formatting, Markdown lint, diff checks and exact reversal of the deliberate fixture changes pass. No build, test or native execution ran in this worker. Root must execute the three original failed methods, related targeting/destruction/station tests and the existing textured-hull acquisition cases before the final composed `make ci`. No runtime pass, renderer acceptance or release is claimed.

A separate read-only caller audit identified additional post-launch legacy targeting mutations in other fixtures. Those findings were sent to Root for bounded ownership and were excluded from the initial four-file fixture correction; the separate authorised follow-up is described below. They must not be presented as executed failures. Existing pre-migration legacy fixtures remain valid and unchanged.

## Separate seven-file caller follow-up

Nine source-confirmed post-launch core installs now use canonical fitting. CR05 ECM timing, Cockpit, the shared Retaliation and Station Approach fixtures, and the native steering-clearance test configure their original tier before launch. The two Gameplay Ordnance Runtime tests, station-cue test and MacBook controls test retain their existing launch-owning helper/order and grant the requested owned core at the existing post-launch setup point. Each verifies a canonical inventory and its actual tier. No implicit paid prerequisite receipts are invented.

The Retaliation equipment-loss scenario stores the actual fitted core using its current inventory revision, verifies the tier is absent and retains all four scenarios and no-launch assertions. The MacBook safety fixture grants a real Energy Bomb in `.utility(.energyBomb)` before Tab, preserving the original bomb-presence assertion and adding identical fitted-item and cash conservation. These are genuine positive/negative equipment fixtures rather than mirror-only string mutations.

All original missiles, ECM, identity replacement, physical tick partitions, target timing, approach motion, HUD layout, trackpad/native key input and assertions remain. No production code, allocation policy, source renderer, skip or test selection changes. Exact reverse-setup proofs reconstruct all seven original files. Strict source/Markdown lint and diff checks pass; compilation and execution remain pending with Root, including focused original cases and final composed `make ci`.
