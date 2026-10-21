# Orbiting formations need a shared world-space steering kernel

## Motivation and required behaviour

FR-047 and the mission formation capability need ordinary and protected mission fleets to follow the same cyclic orbit with persistent ordered slots. A camera-relative centre or model-offset pursuit would move the orbit with the viewer or cut across the planet. Reallocating live-array slots on a loss or scene rebind would also jump surviving goals, and restoring a fresh controller would reset capture progress.

## Scope and compatibility

Add one pure controller and focused tests, plus this issue/PR handoff pair. Its immutable resolved world anchor, logical UUIDs, fixed slots, wrapped phase and cumulative capture budget survive Codable roundtrip. At most 64 slots belong to one formation incarnation; this is not a global NPC cap. G1's ordinary provider and a later protected mission adapter remain the sole owners of membership, actual motion, collision, EMP eligibility, resources, cargo and law.

This assignment adds no runtime adapter, campaign shortcut, actor allocation, save-container change or renderer logic. Existing native admission and mission custody protections remain mandatory. See the [controller result and validation limits](PR-orbit-formation-controller.md). The source is not proof of playable Crimbo or completed mission formation support.
