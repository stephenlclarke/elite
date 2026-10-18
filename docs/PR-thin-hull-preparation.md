# Preserve resolved thin hull surfaces

## Change

Prepare the original Tiger Trader without removing its nonzero face 747 or replacing its collision mesh. The previous aspect-ratio rule rejects that surface before actual work guidance can operate. Preparation now requires an area interval with a strictly positive lower bound. Stored original triangles reach this gate directly, avoiding an unrelated absolute shoelace cutoff; general polygons keep their self-intersection and ear checks.

## Conservative query contract

Every arithmetic operation in the new interval helper rounds its lower endpoint down and upper endpoint up. Products enclose all endpoint combinations, division refuses zero-spanning denominators, and square/root operations include zero and underflow conservatively. Nonfinite or unresolved preparation fails. The old aspect and absolute-area boundaries only route queries: triangles already supported by the previous contract keep the established fast path. Newly accepted thin/small triangles and transformed copies use conditioned queries.

Point-to-triangle queries enclose plane projection and edge-side classification. If the side cannot be proved, infinite-plane distance is a lower bound, not an assertion that the projection lies inside. Proved exterior projections use conservative point/segment bounds. Segment bounds use projection gaps along approximate closest-feature and endpoint axes. Any finite axis supplies a valid convex-set separation lower bound; an inaccurate near-parallel closest-feature calculation can only reduce the claimed gap. Projection subtraction and division are rounded outward too. Triangle separation takes the minimum of these feature bounds, and uncertain intersections return zero rather than disappearing.

Conditioned rays first use outward-rounded slab bounds, limited to the actual segment when testing edges. A resolved determinant and barycentric intervals can prove a miss. An unresolved determinant or boundary interval cannot become a miss: it is retained as an uncertain hit. Parity queries then keep the existing boundary/unproven refusal. Distance interval width also has to fit inside the retained parity merge headroom. Component closure still comes from the original exact-coordinate edge incidence; open interiors remain unproven. All original clearance, continuous motion-envelope, subdivision, triangle-query and node budgets are unchanged.

## Tests and verification

New source checks that SH127 retains its original 3806 vertices, 7016 triangles and face-747 coordinates/indices and remains classified as an open assembly. It covers resolved thin closed surfaces in both windings, interior refusal, safe exterior and continuous crossing with sphere and exact-player modes, open interiors and ray boundaries, true-zero and roundoff-unresolved area, malformed indices/repeated vertices/nonfinite input/self-intersection, scale from 0.000001 through 1000000, translation, strict gap and budget exhaustion. A deliberately collapsed translated thin dimension must throw. The original native human manifest/import and eight/eight test is unchanged and remains mandatory runtime acceptance.

Source formatting, scoped Markdown lint, whitespace and bounded scope/hash checks are the only author-run checks. No compiler, typecheck, discovery, test, runtime, media or remote job is performed in this source allocation. Interval conservatism may refuse an otherwise physically clear query; actual native success, query cost, sanitizer behavior and coverage still need the integrator's execution. A source predicate scan is not all-171 preparation acceptance.

## Compatibility and remaining work

Ship source geometry, appearance/provenance, source-face mappings, save formats, actors, work budgets and controllers are unchanged. The six genuinely zero/roundoff-collinear source faces remain a separate importer/maintained-data repair; this change does not turn them into valid closed surfaces. The integration owner must run one authoritative `make ships` after combined Core freeze, then `make ships-check` and the required `make ci` gates. The existing media dependency includes all Core Swift files, so this applies even without a TOML change. No generated GIF or manifest hash is hand-edited. Main-only SonarQube, final review and protected merge remain required.

## Linked issue

[Thin hull preparation motivation](ISSUE-thin-hull-preparation.md).
