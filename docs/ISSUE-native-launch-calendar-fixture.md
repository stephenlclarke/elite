# Native launch requires station calendar state without creating a mission

Full 222 observes the launch-calendar fixture still requiring the entire script state to be empty and durability to be absent after genuine native launch. The current station world intentionally creates the main station resource and simulation-calendar launch adjustment. The original useful requirement remains: launch must not invent mission calendar, instances, queues or other mission state.

Build the complete expected script state independently from an empty value, adding only the specified 600-second launch ledger/adjustment and deterministic current main-station resource. Retain exact full-state equality and physical/Commander validity, require native durability, and keep every other calendar/refusal test unchanged. See [the correction](PR-native-launch-calendar-fixture.md).
