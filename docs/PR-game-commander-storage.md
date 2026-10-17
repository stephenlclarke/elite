# Preserve commander snapshots with smaller Game values

Instrumented actor-driven launch can exhaust the worker stack while several Game values are live. Game now holds its Commander in private, always-one-element array storage. Public read and modify accessors borrow that value; the standard library detaches it when a copied Game is mutated. This preserves nested value semantics without mutable shared-reference storage or unchecked Sendable.

The public Game/Commander API, Commander serialization, save versions, actor ownership and launch/admission behavior stay unchanged. New regressions cover independent nested inventory/script mutations, whole-commander replacement, snapshots retained across an actual actor XYZZY grant, and actual failed launch publication followed by successful retry and complete saved Commander equality.

The pre-change explicit nominal probe measured `EliteCore.Game` at 16,568 bytes and `EliteCore.Commander` at 7,606 bytes (7,608 stride) on this machine. Post-change measurements, focused tests, affected thread-sanitizer paths, full CI, native checks and reproducible performance acceptance remain pending. No throughput, total-memory or completed-gate improvement is claimed from source review or nominal layout alone.
