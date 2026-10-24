# Physical catalogue mesh lookups rebuild immutable adapters

`gameplayMesh(for:)` rebuilds `ship.design.rawMesh` on every catalogue-ID lookup. That adapter recreates vertex and texture/material mappings from validated bundled definitions. The existing native mesh cache covers Hull identities, while the showroom cache normalizes geometry and cannot substitute for authored physical dimensions.

Retain one immutable raw Mesh per exact bundled catalogue ID. Preserve all authored coordinates, faces/winding, details, materials and UVs, and every earlier special-case branch and unknown-ID fallback. This is a source-grounded performance opportunity; no measured improvement is established. See [the change](PR-catalogue-raw-mesh-cache.md).
