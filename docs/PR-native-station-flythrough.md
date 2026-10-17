# Observe native station geometry during the reported fly-through

## Result

Opt-in native frame profiling now records explicit window, docked, paused, camera, energy, shield and message state, including the state at a refused frame. The original combined guard is split into the same two required conditions with distinct failure reasons. A read-only Core projection returns the actual bound station identity, rendered and canonical poses, source mesh counts/bounds, center range, effective player radius and the same conservative sweep result used by native station collision handling.

An additional `--profile-station-geometry` option captures at most three actual AppKit renderer views for approach, close pass and failed clearance, each with its corresponding sample JSON. Capture draws remain identified and excluded from distinct-draw statistics. The production loop, normal commander, seed, original +Z heading, three-finger throttle, collision behavior, guarded active window, warm-up, trajectory and time budgets are unchanged. This diagnostic does not fix or dismiss the reported visual defect.

## Validation

Source parsing, strict formatting, scoped Markdown lint and whitespace checks precede source handoff. Two focused tests check actual bound source geometry, read-only behavior, unresolved time and refusal of a stale physical binding. Compilation, test execution and the enhanced native capture are pending the sole validation lease. The prior 309 compact protocol result is not native visual acceptance; fullscreen remains incomplete.

## Compatibility and remaining risk

The projection confers no gameplay, docking or collection authority. It performs extra opt-in diagnostic work, so compare performance only with the same instrumentation. A failed conservative sweep is a refused-clearance observation, not an exact penetration depth. Inspect the images and actual state before implementing the geometry or motion repair, then run the relevant regressions and native validation. No full CI, coverage, leak, clean GitHub review or release claim is made here.

## Link

[ISSUE-native-station-flythrough.md](ISSUE-native-station-flythrough.md).

## Structure and physical response correction

Each of the five audited source component types explicitly converts its face convention during assembly. Closed waystation/HQ rock surfaces face outward; open construction and receiving interiors follow their independent front/bore witnesses. All original vertices, embedded source faces, connected topology, source roles, identities and openings remain retained. Waystation effective docking and launch fit use the actual smaller main bore, while the original wider liner geometry remains visible.

The shared native station impact response refuses the attempted player pose and stops cruise, residual/work momentum, rotation and automatic guidance. It reprojects the current actor and celestial poses into the retained player frame instead of restoring old body snapshots, so earlier NPC movement, projectiles, station spin and impact damage remain committed. Original main-station wrong-side collisions use the same stop while retaining their existing doorway/contact predicates. Mission-frame observation occurs after the retained collision endpoint; valid RRS entry keeps its separately swept endpoint and publishes through the existing owner.

New regressions cover exterior faces on both arms, both bore liners, HQ rock/front/eight bay interiors, closed topology and signed orientation, real narrow-bore fit and near-plane straddling panels. Native solid-arm tests drive manual cruise, residual momentum and work braking through the real tick path; separate checks preserve every current actor world pose and stop an original-main wrong-side impact. Existing genuine doorway entry, unsafe approach, automatic docking, save rollback and guided movement checks remain required. These source changes are not yet compiled or executed; the 310 pass applies to the prior diagnostic source only.

## Rotating contact and unresolved geometry

A prior ship pose is not automatically clear of a station at its new orientation. If necessary, contact transport applies only the station's actual rigid rotation to the prior ship pose. It bounds displacement by real surface movement and checks the whole effective hull at the final station orientation and the current surrounding scene. Other actors and physical time remain advanced. A conservative refusal cannot establish physical crushing: an unresolved contact stops and pauses flight with the existing time-scaled impact damage, rather than killing a full-energy commander or claiming a safe endpoint. Invalid initial overlap remains unsupported; no arbitrary outward relocation or station/time rewind is used.

A stationary near-arm regression finds a genuinely clear initial placement against the actual mesh, proves the rotated surface reaches it, and checks bounded contact transport and final hull clearance. Collision-frame conservation now observes an independently moving ordinary NPC through the actual native tick. A separate invalid-start test verifies that conservative uncertainty cannot cause instant death. `stationImpactRevision` marks the actual physical frame so future provider attained-motion observations can refuse calibration credit for contact transport; G1 must join this at the actual post-motion caller.
