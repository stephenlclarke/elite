# Selected ship texture pixels

This source slice adds actual diffuse image sampling for SH169 Sunray and SH170
Military Stingray. It does not texture the entire catalogue. Compilation, focused
pixel/native execution, visual acceptance and the composed quality gate are pending.

The original DAT tokens, per-corner UVs, geometry, source profiles, IDs and custody
records stay unchanged. Each selected TOML adds an independent `resolvedTextures`
binding. DAT `NAMES` resolves numeric tokens; the selected ship definition's
`like_ship` and material overrides select the actual diffuse image. The importer
exposes those resolutions separately from archival preservation.

The three original PNGs are pinned by member and SHA-256 in
`Resources/ShipTextures/manifest.json`. The exact archive matches the two ships'
custody record. The original package README explicitly identifies the Ray and
derivatives as new GearsNSuch artwork, licensed CC-BY-NC-SA-3.0. Full source notices
accompany this limited selection. Unrelated package images are not thereby cleared.

`Tools/showroom/prepare-ship-textures.py` verifies the archive and selected images,
then produces opaque RGBA caches without losing RGB to alpha premultiplication.
Source diffuse alpha carries specular data. The three 1024-square caches occupy
12 MiB; original PNGs add about 3 MiB. Native application startup explicitly warms
the bounded, hash-verified immutable pixels before creating the view and starting
the normal frame pump. Mesh preparation also warms them for non-application media
and test consumers. Failed pixel loading retains the existing flat material
fallback. No AppKit object enters simulation state. The 12 MiB figure describes
resident texels; startup temporary buffers, peak memory and elapsed time have not
been measured.

The shared pure sampler clips camera-space position and UV at the near plane,
projects reciprocal depth and performs perspective-correct bilinear repeat
sampling. Native drawing and bitmap/media exports use that same sampler. Tiles
clip to the scene and adapt sampling resolution to a maximum 4096-pixel axis and
4,194,304 pixels per triangle. Existing face ordering, hull lighting, emissive face
policy and wireframe geometry remain in force; wireframes do not sample textures.

This is a native diffuse adaptation: v=0 denotes the top image row. Cached source
code does not establish Oolite's complete image-upload convention. Normal,
specular, separate emission and shader maps are not rendered, and source renderer
parity is not claimed. Visual validation must inspect orientation, seams, clipping,
readability and native frame cost before acceptance. Texture bytes, manifests and
notices participate in ship media fingerprints; renderer media is regenerated only
after the integrated source has passed its assigned validation.
