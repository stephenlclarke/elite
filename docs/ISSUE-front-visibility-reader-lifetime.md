# Front visibility overlaps station reads with the renderer frame

## Problem and evidence

Hosted CI for committed head 6b6ed6cec08c89e4bf00828c631da99d62acae26 failed in narrowRefinementRefusesOversizeOrientationWallContactAndStaleAttainedMotion. G1 retained the actual helper fault and matched image/dSYM UUID 7D483C42-DCB5-3237-95C8-A159D2258EF4. The captured chain enters the Commander reader through nativeStationBodyIsCurrent, gameplayMesh, Display.draw, visibleInFront, cycleAutoTarget and Game.key. The live fault is in the UnsafeBufferPointer Commander reader closure beneath chkstk. The exact failed allocation and copy cause remain unproved.

## Required behavior

Front visibility must keep the same lazy script-NPC/native-gameplay mesh precedence, complete native station authority checks, front-view override, projection, hidden-face and clipping behavior. Missing world, mismatched binding and destroyed records must continue to yield no visible native station geometry.

## Bounded correction

Resolve the same authorized mesh in visibleInFront before entering Display.draw and pass that mesh explicitly. This separates the actual mesh-reader call from the renderer's owned Game frame. The generic Commander reader, storage, station validator, draw implementation and simulation authority remain unchanged.

## Acceptance and remaining risk

Keep the actual failing narrow-refinement producer, attained narrow positive and rendered-edge regression unchanged. Add genuine launched waystation and headquarters visibility/revocation coverage for all three display styles. G1 owns matching compilation and focused execution; independent bugs/performance/style review follows a passing freeze, then required hosted CI. Source structure proves call-lifetime separation, not measured stack savings or a guaranteed hosted crash repair. See [the implementation handoff](PR-front-visibility-reader-lifetime.md).
