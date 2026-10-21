# Oblique stand-off can request an endpoint inside its required hull gap

RelativeWorkController uses clearanceC=max(120,2R), radiusR and margin1 to place a work point distanceD=C+R+1 along an acquired approacha. It only requires a dot geometric normaln to be positive. For a broad planar face and zero lateral offset, actual normal support gap is D(a dot n)-H, with player supportH. R10/C120 and a60degree approach yield centre distance65.5 and sphere gap55.5, below required120. The existing unchanged HullSweepSafety correctly rejects that gap. This proves a generic destination defect, not the actual cause of G12 owner1175's separate clearance failure; G3 retains its geometry/fixture ownership.

A blanket infinite-plane correction can overestimate stand-off around finite faces and corners. The retained acquired-ray finite-wedge regression demonstrates a valid300range corridor with actual player/target hull sweeps. Its geometry, range and positive/counterfactual/braking/hold oracles must not change to accommodate a formula. Use the existing actual-geometry validator to retain a proven baseline hold and compensate only when that proof fails, then retain the complete ordinary motion/range/braking validation.

See [the correction, callback cost and selected qualification](PR-oblique-work-clearance.md).
