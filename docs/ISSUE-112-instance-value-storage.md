# Issue 112: mission-instance copy stack usage

The retained rescue settlement failure reaches required Array COW initialization with copy of the large inline `ScriptInstanceValue` during `contract._modify`. Moving owned read queries did not remove that required mutation copy. Evidence remains in `/tmp/elite-settlement-remaining-rescue-runtime`; the packet is based on `b1eef289`.

Keep the 51 logical fields, defaults, 14 required codec keys, 37 optional omitted keys, ordered member equality and public `ScriptInstance` API. Replace only the private value's inline payload with a nonescaping private COW reference. Mutation must detach before writing or yielding, including nested optional and collection mutation. Clone one field per returned helper frame after allocating the destination on the heap. Preserve the existing mission, authority, payment, rollback and query oracles.

See [PR 107](https://github.com/stephenlclarke/elite/pull/107) and the [packet handoff](PR-107-instance-value-storage.md). This source checkpoint is unqualified until G1's matching native build, compact-layout and clone evidence, affected tests and remaining rescue cases pass.
