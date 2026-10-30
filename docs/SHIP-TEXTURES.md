# Selected ship texture pixels

This source slice adds actual diffuse image sampling for SH169 Sunray and SH170
Military Stingray. It does not texture the entire catalogue. The combined app compiled
and actual renderer generation/currentness passed for all 171 ships at checkpoint 177.
At that checkpoint, focused pixel/native tests, visual/performance acceptance and
the composed quality gate remained pending.

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

The separate [original fleet texture path](ORIGINAL-FLEET-STAGING.md) uses the authenticated `l337-` assets and authored face materials. Its shared raster preserves the lit original palette while the surface map supplies relief. See [palette fidelity and its exact-source validation](PR-original-texture-palette-fidelity.md). This path retains its own MIT asset custody; it does not change the imported SH169/SH170 image licences.

## Archival texture notes and current selected bindings

The original DAT texture tokens, UV records and import-scope notes remain preserved in SH169/SH170 definitions and appearance/source profiles. Statements such as `reference only, no pixels bundled` describe what the original DAT import established; DAT tokens alone establish neither a bitmap licence nor a resolved image. They do not describe the later selected rendering addition.

For the current selected adaptation, the separate `resolvedTextures` bindings and [texture manifest](../Sources/L337Core/Resources/ShipTextures/manifest.json) identify the three approved diffuse images, exact member/cache hashes and unchanged source notices. Only SH169 Sunray and SH170 Military Stingray use those bindings. Their current selected pixel custody is CC-BY-NC-SA-3.0, as recorded above and in [project notices](../NOTICE.md). Other archival texture references remain unbundled; the addition does not license unrelated images or claim normal/specular/shader parity. Historical profile text, original notices and geometry are retained rather than globally rewritten.

The first combined app compile passed at checkpoint 176, but export failed at its legacy plain-panel guard. The clipped textured-surface export/front-visibility repair then passed actual renderer generation and currentness for all 171 ships at checkpoint 177. Its authored focused tests were still pending at that checkpoint. Later exact-source pixel and palette validation is recorded in the [palette-fidelity handoff](PR-original-texture-palette-fidelity.md); those results retain their original source identity. Successful media generation is not evidence that every flight view has passed native visual or performance inspection.
