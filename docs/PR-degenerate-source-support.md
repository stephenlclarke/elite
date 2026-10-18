# Retain original three-vertex collision supports

## Change

Prepare mixed original meshes without discarding their unresolved three-vertex source primitives. Preparation caches area resolution and support/conditioning flags, requires at least one certified surface in the mesh, and retains every primitive and all original component edges. A degenerate-only component cannot gain solid eligibility from edge incidence. The existing whole-component conditioning policy applies to every containment hit, including broad faces connected to an unresolved support.

## Conservative distance proof

For any finite axis, outward interval projections enclose all three original vertices. The positive gap between projection ranges divided by an upper bound on the axis length is a separation lower bound. Taking the maximum over arbitrary axes remains a lower bound; inaccurate approximate closest features affect tightness only. Point queries use ten bounded axes against the complete three-point convex support. Triangle-pair queries involving an unresolved support use 32 bounded axes against both complete three-point supports. Intersecting supports have overlapping ranges on every axis and cannot obtain positive separation. Filled nonzero interiors are retained even if an area/normal division cannot be certified.

The whole mesh remains the union of original primitives. Its distance is the minimum of primitive lower bounds, and the original maximum vertex radius encloses every convex support. The continuous linear/angular envelope, required clearance, strict numerical headroom and subdivision/query budgets are unchanged. Candidate axes that are nonfinite or cannot be normalised contribute zero, not safety. Coordinate axes ensure that resolved exterior gaps can still produce useful positive clearance.

For meshes or query triangles with unresolved support, BVH pruning uses outward-rounded box-distance lower bounds and an upper bound on the square of the current best lower bound. A discarded node therefore has true distance at least that best bound. A truly closer primitive cannot be pruned by this certificate. Ordinary traversal-order heuristics do not grant clearance; nodes and primitive queries retain their original charges.

Support projections enclose the represented Double geometry. The existing pose conversions use two affine transforms, at most 36 elementary operations per vertex with validated near-orthonormal basis components. Their forward error is bounded by a small multiple of gamma(36) times the same radii/position magnitudes already present in the retained `1e-8` numerical headroom. Underflow is dominated by its minimum unit scale; overflow cannot produce an authorised finite separation proof. Thus no normal-conditioning error or new unchecked pose-error exemption is introduced. Pose/scale/translation and native acceptance still require genuine execution rather than assuming this source argument is a measured result.

## Ray and containment proof

Outward slab intervals enclose every possible intersection with the primitive's original vertex bounds. For an unresolved primitive, interval endpoints enclose the finite ray candidate segment. Fifteen fixed candidate axes can certify a positive separation between that enclosed segment and the full original support, proving a ray miss without any area division. Otherwise interval determinant/barycentric predicates must certify the outcome; a zero or unresolved determinant is a boundary/unknown result, never permission to skip the primitive. Alternate containment rays or the existing unproven refusal handle uncertainty.

All containment hits in a component with thin/small/unresolved supports remain conditioned. Distinct close broad-face crossings cannot be merged into a fictitious exterior. Exact original component edges and open-interior refusal are retained. A component with no resolved surface remains ineligible for solid containment, even if its incidence table is closed. No source face is removed and no closed flag is forced. Positive separation outside an original component bounding box is useful; unresolved interior or ray classifications may still refuse honestly.

## Tests and verification

The new future inventory calls actual `PreparedHull` for SH001 through SH171 as separate declared arguments without filtering. A separate source test checks all six retained face indices and complete triangle counts on SH038, SH066 and SH154. Synthetic tests include an original segment with exact point distance 5 and radius-1 clearance 4, a nearly collinear but nonzero filled triangle with an exactly representable interior point, separated and crossing sphere/exact-player motion, a degenerate-only closed-incidence component alongside a genuine closed box, BVH near/far source-order permutations and a genuine closed cube with its covered zero seam retained. They include positive useful clearance as well as collision/interior negatives. Existing standalone-degenerate/malformed, thin-bridge, budget and actual SH127 eight-plus-eight assertions remain unchanged.

Source checks are static only. Compilation, discovered argument counts, execution, all-171 inventory results, native work/collision, performance, coverage and sanitizers/leaks are not claimed. The integrator owns one combined compile/runtime lease; source inventory is not acceptance. No producer/model/UV/source-profile or saved-world authority is rewritten. After the reviewed combined Core freeze the integrator must regenerate ship media once with `make ships`, verify `make ships-check`, and complete required `make ci`, review, main-only exact-SHA analysis and protected merge gates.

## Linked issue

[Original source-support motivation](ISSUE-degenerate-source-support.md).
