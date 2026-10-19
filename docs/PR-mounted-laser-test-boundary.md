# test(weapons): separate mounted damage from selected-tool input

The existing mounted-laser equipment test now calls the maintained `Game.fireLaser()` operation after each original neutral cooldown tick. That operation derives the mount from the actual view, rejoins the fitted equipment, performs native geometry/law attribution, applies its real damage and records its own cooldown and heat. No test shadow kernel or forced hit is introduced.

Every original mount, target position, fitted-item assertion, damage expression, first0.01-second and second0.1-second interval, rate calculation, heat predicate and empty-rear-view assertion remains exact. In particular the Mining Laser still must deal50 damage through the mounted kernel; it is not replaced with another laser or a weaker expectation. Only the old selected-combat Return route is removed from this equipment-kernel test.

A companion test installs the same front pulse/left mining/right beam layout, verifies the real left fitting, keeps Combat Laser selected, and submits held Return in the left view for those two intervals. The target must remain100, with zero heat/cooldown and no energy/audio consumption; the selected tool must remain Combat Laser. This directly protects the current human-input behavior rather than permitting an unselected work tool to emit.

## Evidence and preserved behavior

CI593's literal100-versus50 and missing heat identify the mining branch. `FlightWorkTools.fireSelectedFlightTool` requires a non-mining mounted laser in its Combat Laser branch. `MiningWorkTool.fireMiningWorkTool` separately requires the front view and a current verified asteroid/rock source, with ships, stations and celestials acting as occluders. Existing `MiningWorkToolTests` exercise actual selected mining emission, front-fit fallback and obstruction refusals. The user-visible W/Return tool choices in the control guide remain unchanged.

No production source, Game layout, actor ownership, schema, safety latch, fitted equipment, damage, rate, collision/law guard, EMP behavior, cooldown timing, default stack or test budget changes. The exact parent is0482eb88a3c549b60bbe382bb21e7d8715ef1bc7; canonical3a3529fb is a documentation-only descendant with the same Sources/Tests. G1 owns the separate crash and rollback paths; this leaf touches only StationTests and these paired notes.

## Validation

Reversing the direct mounted calls and original control declaration, then removing the one companion test restores the entire parent StationTests file byte for byte. All original assertions and the remaining test methods are untouched. Author checks are strict Swift formatting, paired-note Markdown lint, whitespace checks and exact source correspondence. No author compiler, runtime, native, GUI, profile or diagnostic job was run.

G1 owns one independent review and the coherent batch compile with the other ready reviewed repairs. Focused selection is `laserMountDamageRateAndEmptyViewsUseTheirOwnAuthoritativeEquipment`, `heldCombatReturnCannotDischargeAFittedSideMiningLaser`, `fourMountsStartWithOnlyFrontPulseAndPurchasesReplaceOnlyChosenMount`, the unchanged mount-save regression, and `MiningWorkToolTests` for selected forward mining and obstruction safety. Existing FlightControlInput held/fresh-press/EMP interruption checks remain unchanged. No full-CI retry or completed runtime-validation claim follows automatically from this source leaf.
