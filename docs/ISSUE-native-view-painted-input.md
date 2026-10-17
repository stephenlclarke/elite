# Native control fixtures must supply current painted page proofs

## Problem

Native view tests still expect raw arrow, Return, Tab and page-key strings, or the former handoff-click packet. Production input protects those actions with the actual painted page presentation. The work-guidance fixture sends Tab and R before any native draw, so those targeting inputs cannot carry a current presentation and guidance never engages.

## Acceptance

Draw the actual current view before ordinary protected input and decode the packet the view really emits. Check the exact key or converted pointer coordinates and painted presentation. Keep real delegate consumption, held-key release, momenta, selected actors, tool resources, custody, private save bytes and rendering timing assertions. Do not manufacture proofs, change production input or repaint deliberately unpainted adversarial cases.

## Validation

Review the narrow fixture changes and run the affected native input and work-guidance methods under the central validation lease. Source formatting and documentation checks precede integration; native results remain pending execution.

See [the implementation](PR-native-view-painted-input.md).
