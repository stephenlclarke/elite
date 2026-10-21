# Showroom restores an unrelated cockpit clip after textured previews

## Evidence and cause

Checkpoint 202 fails shaded surface recognition for SH169 Ray Mk I and SH170 Military Stingray. The recorded frames contain real textured triangles and loaded diffuse assets within the showroom preview pane. `showroomScreen` sets its responsive canvas but retains the default 256 by 164 cockpit flight clip. Each model temporarily applies its correct pane clip, then restores that unrelated default. The surface query intersects texture clips with the restored frame clip and rejects both actual textured hulls.

## Required correction and scope

Initialize the enclosing showroom clip to its actual canvas. Preserve the temporary per-model pane clip and restoration, texture assets, importer, surface query and all source-model/surrogate/wire/rotation checks. This is frame metadata correction, not a fallback model or an assertion exemption. See [the implementation](PR-showroom-texture-clip.md).

## Validation and limits

Source confirms the clip mismatch and actual triangles in failed evidence. Strict formatting and diff checks pass; no rendering or runtime execution ran in this worker. The integration owner retains validation. Checkpoint 202 does not prove a completed suite pass.
