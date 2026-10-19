# Original textured faces lose their authored palette colour

The successful textured branch in Display reads the per-face material but shades only white into scalar brightness. The triangle and raster then render source texture RGB without material colour. Consequently two original faces with identical geometry, UVs and lighting render identically even when their TOML palettes differ. This is established by source data flow, not a new native screenshot.

The frozen UX handoff, handoff-20261019-reconciliation-g2/FIDELITY-FINDING.md, identifies the original authoring renderer's contract: shade actual material RGB, then modulate it by surface relief bounded to clamp(meanTextureRGB / 86, 0.27, 1.10). Preserve original assets and mappings. See [the correction and validation limits](PR-original-texture-palette-fidelity.md).
