# Coherent native source invalidates ship media fingerprints

## Observed failure and cause

PR21 head71397cf83a860db777e2c19a4025f82b4708ff0f failed hosted quality39419186509 at ships-check. All171 renderer input fingerprints were stale after later native source changes. The conservative shared_hash intentionally includes every top-level EliteCore Swift file, NativeGraphics/ShipMedia, the pinned package dependency and ship textures. Thirty-one shared inputs changed after the previous ff52 media checkpoint. This is content invalidation, independent of the synthetic PR mergeSHA, embedded build identity or encoder/toolchain differences.

Every existing GIF output digest matched the manifest; no image was missing or tampered. Flight controls, distribution tests and cask verification passed before the stop; coverage, Thread Sanitizer, Address Sanitizer and leaks were not reached. Dependency review passed. The requested review also terminated with an unknown service error and produced no completed review or actionable finding. These remain failed/unsatisfied gates.

## Repair and scope

Run maintained make ships once with the actual renderer and unchanged fingerprint/check policy, then validate all frames and freshness. Do not hand-edit the manifest, alter source, regenerate unrelated README media or repeat full local CI. Preserve raw failed-run evidence and submit the generated correction through the same draft PR for new-head checks/review. Companion: [PR-ship-media-freshness.md](PR-ship-media-freshness.md).

## Post-compatibility renderer refresh1006

The bounded Swift expression source correction necessarily invalidated the conservative shared inputs again. After aggregate local9methods11cases qualification and canonical source integration1d591ed2ee700e355ddd120adf25f2ec6ba76ae3, one maintained make ships1006 regenerated all171ships using byte-identical coherent Sources/resources/Package/renderer/generator/Makefile inputs in the existing warm qualification checkout. Execution65.100seconds/outer66.001seconds stayed within600/640 limits. All73 observed actual owned starts were independently absent; no timeout/cleanup, all maintained inputs/preferences/README exact, lease released.

Only171 manifest input values changed. Every GIF/output digest and catalogue/provenance table is byte-identical. All4,104frames decoded nonblank at256x256/24frames/100ms; make ships-check passes. Qualification `/tmp/elite-ship-media-refresh-1006/qualification.json` SHA256 `f51c37c9299c55b34b4913641750ace0fee480590a1d270e92ad505ec40bd44a`; renderer log SHA256 `45704858701c808c05bb07ee19015f53e31a63fff563fe4299c5c776845509f4`. No README generation, hand-edited fingerprint, weakened check or local fullCI replay. This final corrected head still requires actual hostedSwift6.1.2 acceptance and clean required review; prior hosted/service failures remain retained. M01 and release remain open.
