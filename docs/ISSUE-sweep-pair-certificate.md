# Visited BVH leaves still evaluate irrelevant triangle pairs

Exact player/obstacle distance queries already traverse immutable BVHs, cache actual query-local transformed player geometry, and conservatively exclude node pairs and whole triangle/leaf rows. Inside a surviving leaf pair, every remaining primitive pair runs the complete triangle feature kernel even when the two individual triangle boxes prove that pair cannot improve the current best distance.

The complete ordinary pair kernel can perform six edge-ray tests, six vertex-to-triangle tests and nine edge-pair tests. Avoiding that kernel for provably irrelevant pairs is a larger algorithmic opportunity than another immutable scalar cache. Retained historical samples identify the mesh distance path; they do not establish the exclusion frequency or net benefit for the current salvage scene.

## Required behavior

After the existing paid pair charge and row certificate, replace only the feature kernel when the existing outward box lower bound proves that this ordinary resolved pair cannot improve the finite current best. Preserve all traversal, query/node/pair accounting, work-budget exhaustion, continuous proof and public authority. Conditioned, support, unresolved and nonfinite cases retain the original feature kernel.

Use an independent analytic clustered mesh regression for distance, threshold behavior and exact paid work, and retain the existing geometry regressions unchanged. Compilation, execution and performance assessment belong to the coordinator's sole executor.
