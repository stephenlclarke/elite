# Mining fixture initializes hardware after canonical inventory exists

## Evidence and required correction

Full CI checkpoint 216 reports missing mining/cutter fittings, missing four Naval facings, failed actual mining emission/damage/audio and an unsupported-hull negative that did not throw. `workToolGame` launches before seeding legacy maximum hardware and calling `initializeEquipment`. Launch has already prepared canonical inventory; initialization therefore returns without fitting those later seeds.

Move the same legacy hardware, mount, XYZZY and explicit owned-inventory initialization before the original launch. Require the intended actual tools, facings and matching station-world owner. Keep all existing resource, collision, depletion, audio, storage and unsupported-hull assertions. This is a fixture prerequisite correction; no production getter or provider exception is justified.

## Validation and limits

Strict Swift/Markdown lint and diff checks pass. Source reversal verifies the bounded changes preserve the rest of the original test files. No compilation or execution occurred in this worker; checkpoint 216 remains failed evidence. Focused execution and required composed `make ci` remain with the integration owner. See [the implementation](PR-mining-work-tool-fixture.md).
