# Rotating ships lose visible wireframe segments

## Problem

The previous winding correction left two warped quadrilateral side faces in the Cobra, Viper, Sidewinder and missile meshes. Culling each side with the plane of its first three vertices sometimes hid a visible outline edge. The title ship was also large enough to cross the wireframe clipping boundary and version text at some orientations.

## Expected behaviour

Every projected silhouette segment remains visible throughout a complete combined pitch and roll cycle. Rear faces remain hidden. The title ship fits between the heading and version text at every angle.

## Acceptance

- Reproduce the missing silhouettes with an independent projected convex-outline test.
- Require every mesh face to be planar, convex and consistently outward-facing, with two faces per edge.
- Check all eight hulls over 720 orientations each and title-screen endpoint continuity and text clearance.
- Preserve the original-style font, smooth wireframe strokes and number-key controls.

Implementation and validation: [PR-ship-wireframe-segments.md](PR-ship-wireframe-segments.md).
