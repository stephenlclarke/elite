# Preserve the authored original fleet before runtime integration

The approved fleet packet contains 171 independent specifications and 94 original hull definitions. Runtime catalogue, units, accommodation, policy and texture contracts still require integration; substituting legacy meshes, profiles or balance values would conceal those gaps. Preserve the original inputs and exact-ID joins in an explicitly inactive staging tree, reporting missing meshes and loader dependencies without inventing values.

The isolated MBA implementation and G3 review produced the compiler and focused tests described in [PR-original-fleet-staging-compiler.md](PR-original-fleet-staging-compiler.md). This source integration activates no ships and is not a playable-feature or release milestone.
