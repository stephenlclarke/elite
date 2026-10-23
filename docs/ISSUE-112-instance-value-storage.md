# Issue 112: mission-instance copy stack usage

The retained rescue settlement failure reaches required Array COW initialization with copy of the large inline `ScriptInstanceValue` during `contract._modify`. Moving owned read queries did not remove that required mutation copy. Evidence remains in `/tmp/elite-settlement-remaining-rescue-runtime`; the packet is based on `b1eef289`.

Keep the 51 logical fields, defaults, 14 required codec keys, 37 optional omitted keys, ordered member equality and public `ScriptInstance` API. Replace only the private value's inline payload with a nonescaping private COW reference. Mutation must detach before writing or yielding, including nested optional and collection mutation. Clone one field per returned helper frame after allocating the destination on the heap. Preserve the existing mission, authority, payment, rollback and query oracles.

See [PR 107](https://github.com/stephenlclarke/elite/pull/107) and the [packet handoff](PR-107-instance-value-storage.md). This source checkpoint is unqualified until G1's matching native build, compact-layout and clone evidence, affected tests and remaining rescue cases pass.

The first compact-facade image compiled and completed 100 unaffected cases. The new NaN fixture imposed an incorrect expectation on shared Array/Dictionary buffers; its corrected single method then passed separately. The remaining rescue run still hit a real guard fault in `Storage.copySavedGlassMeridian`: an owned child temporary preceded assignment into the heap field. The repair therefore covers all 18 optional struct children together, with separate private Array COW handles. Class children and small scalar/collection fields retain their existing representations.
