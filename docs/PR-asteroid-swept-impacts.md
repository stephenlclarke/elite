# feat: add native swept debris contact core

## Contact and ownership

Two movement-only hooks capture actual pre-movement actor identities, poses, velocities and meshes, then consume that synchronous reference-owned frame immediately after movement and before station entry/endpoint observations. No stored Game fields or whole-Game candidate are added. A frame is single-use and same-system, same-visit and same-clock; a stale or consumed frame cannot rewind later state. No prior trajectory is invented by back-propagating a current velocity.

HullSweepSafety.firstNativeContact uses the existing PreparedHull triangles, closed-component checks and bounded distance/BVH work. Each discarded interval has a continuous lower-separation proof including relative acceleration and angular envelopes. Adaptive refinement retains a bracket only with a conditioned edge/triangle witness or certified closed-hull surface containment. Missing a tiny/high-speed crossing cannot return clear: lack of proof at the subdivision/work bound refuses the movement. Initial overlap and unresolved geometry also refuse. Bounding radii only reject impossible candidates; they never authorize a contact or damage.

The live collision producer joins exact current actors again before committing, preflights the native collision event capacity/law, and constructs a non-Codable receipt only after applyCombatHit(kind: collision) accepts the real effect. That existing kernel owns player shield/energy changes, NPC shields/resources, physical destruction and death IDs. Collision law creates no weapon discharge, bounty or player reward. Actual source and descendant poses/velocities persist through the existing mining observation/custody boundary.

## Simulation policy

Collision masses are explicit new tuning values, not fabricated ship specifications: Cobra/Constrictor/Thargoid 100,000 kg, Viper 45,000 kg, Sidewinder/Thargon 25,000 kg, station 1,000,000,000 kg. Debris always uses its exact retained commodity kilograms instead. Restitution is 0.15. The impact policy explicitly maps one collision-space velocity unit to one metre per second for damage tuning only, with 10,000 dissipated joules per native energy unit. This does not reinterpret mesh radii as metres or claim catalogue density.

The response exchanges equal/opposite linear impulse along the actual contact face normal and dissipates only the normal relative kinetic energy. Tangential linear velocity is retained. The conservative bracket frontier starts the post-impact path. Every remaining swept interval must also be proved clear before the effect commits; a second unresolved contact defers the entire movement rather than integrating an unchecked remainder. At most 32 candidate pairs are charged in a step, in addition to the existing finite per-query geometry work. Invalid mass/speed/normal, exhausted counters or unproven remaining motion retain captured movement and show an explicit deferred-contact pause. No source mass is deleted or reissued. Native orbital/work acceleration is retained for unaffected trajectories and interrupted by an admitted physical impact on the player.

## Authored validation and limits

Pure cases cover a thin fast crossing whose endpoints are both clear, a continuous near miss, exhausted geometry refusal, finite equal/opposite momentum, tangential velocity and dissipated energy. Native adapter fixtures cover actual generated/registered asteroid breakup, controlled exact native endpoint movement, proved player/NPC contact, ordinary shield/resource effects, physical death IDs without player reward, retained mass/momentum, current roundtrip and consumed/stale-frame refusal. They do not substitute map positions or mission flags for geometry.

Strict Swift formatting, Markdown lint and whitespace checks are the only author checks. ZERO compiler, native app, GUI, test, CI, ABI or profiler jobs were run. Tests are authored, not executed. Stack size, frame performance and actual acceptance remain unverified pending the coordinated central build.

## Remaining required station authority

This is an independent contact-core checkpoint, not full feature closure. Station contacts currently defer with STATION MOTION AUTHORITY UNAVAILABLE. NativeStationSavedPose retains an immutable authored source position and validates that source identity; original main stations have immutable source anchors. The authorized next slice must add separate authenticated current translation/impulse custody, project actual moving bodies/doorways, retain current displacement/velocity across save/re-entry, and apply proven contact damage to actual main/RRS resources. An anchored invisible momentum sink, raw station-destroyed flag or mission reward is not an alternative.

Mission-profiled inertia also refuses rather than directly rewriting mission-owned resources; its sealed contact adapter must be coordinated with NativeMissionImpact. Existing AUTO APIs, beam/fatal branches, procurement/finance and Ship paths are untouched. Full debris hazard and The Shattered Wake remain OPEN until station/mission integration and central validation complete. See ISSUE-asteroid-swept-impacts.md and PR-physical-asteroid-fragments.md.
