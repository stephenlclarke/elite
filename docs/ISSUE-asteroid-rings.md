# Add sparse asteroid rings with honest charts and finite ore sources

FR-009 and FR-012 require maps and system details to identify actual star-centred asteroid rings at twice the planet-star distance. Rings must be sparse, with chunk quantities 1, 5, 10 and so on through 50, and body colours indicating ore content while mineable HUD/glow cues remain orange. Existing fields instead appear between the planet and sun in every system, with a fallback shell centred on the planet. Chunk radius and old ore yields are independent.

Changing old field identities or canonical yields would corrupt saved partial damage, depletion and pending ore. Preserve their namespace and generator, introduce a separate ring namespace and bounded ledger mask, and derive quantities, body materials and map presence from one authority. Existing wreck source positions also need protection. See [implementation and integration requirements](PR-asteroid-rings.md).
