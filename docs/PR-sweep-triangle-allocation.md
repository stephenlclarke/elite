# Preserve swept geometry checks without temporary triangle arrays

Private triangle access now returns one vertex or edge directly. Point-to-triangle and triangle-pair distance calculations visit the same three vertices and three directed edges in the same order, with the original early ray intersection, inside-plane test, strict minimum comparisons and segment arithmetic. No geometry, tolerance, traversal, query counter, safety budget, actor state or serialization changes.

An analytic regression covers face, edge and corner separation for a sphere and an exact player box in both winding directions. Existing closed-interior, concave notch, rotation, moving-obstacle, subdivision and exhausted-budget tests remain unchanged. This is source-only work based on `db027406b34360986e028b11a1d0e3e1499a5c65`; compilation, tests, matching before/after timings and native/full CI acceptance are pending. No FPS, allocation count or measured speedup is claimed.

Only this owned commit should be integrated after the active 247 process closes and its exact artifact/protected-input verification finishes. The canonical checkout, cached artifacts, original test command and its limits remain untouched by this isolated preparation.
