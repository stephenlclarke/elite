# Oolite source coordinate adapter

Pinned O08 Universe.m, coordinatesForPosition:withCoordinateSystem:returningScalar:, establishes the legacy three-letter coordinate strings used by expansion encounters. [Primary-source manifest](data/primary-source-files.json) fixes its revision/hash. This contract is source-derived; it is not a claim that arbitrary project distance units equal physical metres across every other edition.

First letter selects origin w witchspace exit, p main planet or s sun. Second letter selects the feature on the positive Z axis; it must differ from the origin. The remaining feature defines the reference plane. For example, wsm means witchpoint origin, sunward Z axis and metre scale; wsu uses witchpoint-to-sun distance as its scale. Coordinate [0,122000,0] in wsm is a large displacement normal to the system plane, not122,000 along the flight lane.

Let p0 be the selected origin, p1 the selected Z feature and p2 the remaining feature. Source computes k=normalizeOrZ(p1-p0), v=normalizeOrX(p2-p0), j=cross(k,v), i=cross(j,k). Then worldPosition=p0+scale*(localX*i+localY*j+localZ*k). **The source does not normalize j or i after the cross products.** Their transverse lengths therefore depend on the angle between k and v; an orthonormalized adapter changes original encounter positions. Use the source formula for a selected fidelity profile. A deliberately orthonormal project variant must be separately labelled.

Third-letter scale m is1; p is planet radius; s is sun radius; u is distance(p1,p0). Missing sun/planet or abs returns the vector unchanged, including interstellar space. Source invalid strings return zero. For a repaired project profile, reject invalid authored coordinates with a diagnostic rather than silently spawning a target at the origin.

NormalizeOrZ/NormalizeOrX mean the selected O08 vector helper's fallback basis when its input cannot be normalized; keep those fallbacks consistent with the pinned source rather than inventing a random axis. A collinear system can collapse transverse vectors in the original formula. Any project correction for that case must be stable, saved and explicitly recorded.

Source route fractions and legacy_addSystemShips are separate APIs and must not be interpreted as three-letter local vectors. Apply their selected lane/route readers instead. Store the world anchors and generated encounter identity/seed for an accepted mission; changing unrelated UI or loading a save cannot move its target to a newly rolled site.

Verify all six origin/axis permutations, each scale suffix, abs, interstellar/no-sun, parallel/degenerate anchors, positive/negative Z and lateral offsets against the source formula before enabling coordinate-based campaigns. This shared adapter supports Feudal gates, assassination rendezvous and other explicitly bound expansion encounters.
