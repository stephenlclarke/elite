# Check actual textured geometry throughout every portrait rotation

## Change and preservation

The existing full-rotation test now uses `hasShipSurfaces` for shaded visibility, covering flat panels and loaded textured triangles with positive clipped area. Its original flat-panel finite/in-viewport assertion remains unchanged. A separate loop checks every actual textured triangle in both graphic collections for exactly three vertices, valid finite coordinates and perspective attributes, points inside `flightClip` and an identical triangle clip.

All 171 catalogue models and 24 angles remain. No production code, source meshes, textures, materials, projection, fallback, test selection or skip changes. This keeps visibility, finiteness and framing meaningful for both surface types. See [the observed cause](ISSUE-portrait-textured-surface-invariants.md).

## Validation and remaining risk

Strict Swift/Markdown lint and diff checks pass. Reversing only the presence predicate and added triangle assertions reconstructs the entire original `ShipTradeTests.swift` at `6ac264d3a45a966ea58e7048bec9d3cb1fc66a57`. This worker has not compiled or executed the change. The integration owner retains review and runtime validation after the active full CI run; no runtime acceptance is claimed here.
