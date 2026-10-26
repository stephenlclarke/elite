# Complete showroom inspection controls and physical comparison

## Problem and authority

M02.P04's retained shared automatic rotation does not satisfy the later Meridian inspection contract. At design commit `8c899a7e0d351551498b05a7b371b84758575085`, `docs/meridian/missions/gameplay/GAMEPLAY-SPECIFICATION.md:95` and `missions/GAMEPLAY.md:448` require shared drag/axis rotation, a true view reset and comparable calibrated scale. Source commit `17a4297c` has only an automatic angle and pause/resume; R restores the baseline, while independently normalized previews conceal relative size.

## Scope and acceptance

Provide bounded model drag, explicit pitch/roll/yaw controls, a separate view reset, and a common metre scale when both displayed hulls have existing approved physical contracts. Disclose missing calibration. Preserve R's baseline action, search/trade contexts, unknown-hull silhouette policy, comparison values, purchase gates, cargo/property and commander state. No new hull calibration, activation, discovery or acquisition permission is authorized.

## Validation and compatibility

Six focused unit methods must exercise actual shared rendered transforms, full axis turns and reset, scale projection and disclosure, buttons/help/search scoping, refused exchange and actor input guards. Retain all existing selectors. Local formatting, report fixtures, Markdown and whitespace checks precede hosted Swift execution and independent bugs/performance/style review. Native journey, GUI, broad CI and release acceptance remain with G1; source coverage alone is not delivery.

See [the implementation note](PR-m02-showroom-manual-view.md).
