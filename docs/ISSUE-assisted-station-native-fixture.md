# Preserve native station authority in the assisted docking fixture

The retained public assertion ended with docked false and a docking-collision message. Its large Game value was read only through bounded scalar extraction; the original evidence does not name a precise failed docking guard.

The existing test genuinely launched and registered its main station, then replaced that body with an arbitrary tilted camera-space station. Native docking requires the current registered world pose as well as its actor identity. The fixture now uses the established StationApproachTests observer-reframe pattern to present that actual station at the same position and tilt, retaining its negative model spin. New fixture checks assert the exact relative position, orientation and anchored actor.

The original selected-station identity checks, seven-thousand-step 0.02-second budget, actual dock assertion and target-switch/cancel checks remain. After a real relaunch the second cohort uses the freshly launched actual station instead of restoring the stale first-visit body. The shared assisted helper, other methods and all production authority, geometry and docking guards are unchanged; no docking receipt or registered station pose is fabricated.

## Validation

MBA formatting and strict lint pass. Inverse removal of the two fixture edits restores the whole original test file. Copied source hashes, ASCII, Markdown lint, diff and exact scope are checked at freeze.

G1 owns three existing methods/cases: the failing assisted method, the native forward/behind/tilted/fast approach method and the narrow oversize/orientation/contact/stale-motion refusal method. One complete three-path independent review follows actual owner PASS. No author native job or hosted CI repair claim.
