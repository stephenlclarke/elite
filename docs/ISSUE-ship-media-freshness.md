# Coherent native source invalidates ship media fingerprints

## Observed failure and cause

PR21 head71397cf83a860db777e2c19a4025f82b4708ff0f failed hosted quality39419186509 at ships-check. All171 renderer input fingerprints were stale after later native source changes. The conservative shared_hash intentionally includes every top-level EliteCore Swift file, NativeGraphics/ShipMedia, the pinned package dependency and ship textures. Thirty-one shared inputs changed after the previous ff52 media checkpoint. This is content invalidation, independent of the synthetic PR mergeSHA, embedded build identity or encoder/toolchain differences.

Every existing GIF output digest matched the manifest; no image was missing or tampered. Flight controls, distribution tests and cask verification passed before the stop; coverage, Thread Sanitizer, Address Sanitizer and leaks were not reached. Dependency review passed. The requested review also terminated with an unknown service error and produced no completed review or actionable finding. These remain failed/unsatisfied gates.

## Repair and scope

Run maintained make ships once with the actual renderer and unchanged fingerprint/check policy, then validate all frames and freshness. Do not hand-edit the manifest, alter source, regenerate unrelated README media or repeat full local CI. Preserve raw failed-run evidence and submit the generated correction through the same draft PR for new-head checks/review. Companion: [PR-ship-media-freshness.md](PR-ship-media-freshness.md).
