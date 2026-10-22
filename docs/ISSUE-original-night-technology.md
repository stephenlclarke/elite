# Retain authored world technology in night lighting

Ledger M06.P03 / F19: original-world technology uses the validated authored range1-20, but PlanetNightProfile currently clamps every system to the legacy0-15 range. The current catalogue has125 worlds at levels16-19, all flattened to15 by that join.

Use the catalogue's actual minimum and maximum to normalize original-world night development. Preserve the explicit legacy profile constructor and legacy StarSystem behavior, including their0-15 coefficients. Keep economy/government art coefficients, daylight appearance, terrain, identity, belts, ore materials and all physical/thermal rules unchanged. Do not invent a blend of additional authored scalars.

Acceptance: actual catalogue worlds retain their technology; matched-fact original profiles distinguish16-19 and honor endpoints1/20; legacy coefficients and bounds remain exact. This is a pure presentation-data correction, not a new visual/performance qualification.
