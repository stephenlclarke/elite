# Initialize the showroom clip from its responsive canvas

## Change

`showroomScreen` now assigns `frame.flightClip = frame.canvas` immediately after setting the actual canvas. Model previews still use their own pane clips and restore the enclosing clip afterward. Textured surfaces therefore retain a meaningful enclosing viewport for the existing surface query. See [the failure evidence](ISSUE-showroom-texture-clip.md).

## Preservation and compatibility

The existing all-source-model test additionally verifies that the enclosing clip equals the canvas. Its actual surface, empty wire, missing-model surrogate and rotation assertions remain. No texture pixels, importer/material bindings, projection, triangle clip, query semantics or Core crash-path code changes.

## Validation and risks

Strict Swift/Markdown lint and diff checks pass. Source inspection confirms only the enclosing clip initialization changes production behavior. No build, native rendering or test execution occurred in this worker. The integration owner must validate both textured hulls and the complete existing showroom test before the required composed `make ci`; no runtime acceptance is claimed here.
