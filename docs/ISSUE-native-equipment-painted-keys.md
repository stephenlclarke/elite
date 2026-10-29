# Native equipment fixtures must use painted keyboard proofs

## Problem

The native equipment fixture sends navigation keys without painting a current frame and expects raw key strings. Production input now carries the actual painted page presentation for protected controls, including arrows and page keys. Missing paint can refuse navigation; a correctly queued navigation action is also incorrectly rejected by the fixture's raw-string expectation. The inventory fast-focus case has the same obsolete assumption for Tab.

## Acceptance

Paint the actual view before ordinary fixture navigation and verify the emitted packet's decoded presentation and key. Keep equipment Return on its dedicated painted purchase-intent path and continue consuming all input through the real delegate. Preserve deliberate missing-paint, stale, duplicate, focus, pointer/window, fitting, price, commander and save assertions.

## Validation

Source review must confirm that no selection is directly changed, no proof is fabricated and adversarial queued input is not automatically repainted. Run the native equipment regressions under the coordinating validation lease. No native execution result is claimed before that run.

See [the implementation handoff](PR-native-equipment-painted-keys.md).
