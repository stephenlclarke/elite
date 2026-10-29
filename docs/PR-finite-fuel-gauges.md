# fix: normalize fuel gauge fractions before rendering

Exact base 9368440e786511633d9ac1a329af04ce9f768479. Both existing fuel-gauge tuple sites reuse Game.equipmentResourceLevel with target capacity one. This static numeric helper returns zero for nonfinite fuel, nonfinite capacity or capacity at most zero and clamps valid ratios just as the existing bars do. It creates no Game instance and mutates no state. Colors, labels, coordinates and layout calculations stay unchanged.

Make the existing legacy scalar bar method internal for a focused source regression through its actual Frame rendering boundary. The test requires finite empty fractions and no green pixels for invalid/zero capacity and nonfinite fuel, then exact existing half/full/overfull green line coordinates and pixel counts for normal fuel. Both production sites bind the same helper; no invalid Commander or Newt fixture is introduced. The private modern gauge remains unchanged.

Swift/render/compiler/native/GPU/GUI/CI/profiler execution is UNRUN on MBA. Only bounded Python numeric/source checks and portable-patch checks are permitted here. No new numeric framework, game/fitting/refuel policy change, authored data, R edits, fleet admission or activation. See ISSUE-finite-fuel-gauges.md and validation.json.
