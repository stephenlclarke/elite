# Let the owning Blackjack handoff consume its reserved firearm

Exact-binary diagnostic 296 reproduced a real refusal at Galaxy 2/system 127: the player held one marked firearm, the mission was at deliverFirearm, and Confirm returned MARKED MISSION CARGO REQUIRED. The generic mission cargoRemove action checks sellableCargo, which intentionally excludes the marked firearm. Actions run before the completed transition updates the legacy mission stage, so the owning handoff cannot consume its own reserved item. Ordinary sale and foreign mission protection must remain intact.

The same diagnostic showed the automatic trader sold its first load and bought a new 30t load for system 154. The old test compared only cash before and after reinvestment. Verify actual sale profit and exact sales/refuel/purchase accounting instead, preserving the route and loaded-cargo checks.
