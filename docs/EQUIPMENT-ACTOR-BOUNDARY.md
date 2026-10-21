# Buying and fitting through the simulation actor

`GameRuntime` owns the running `Game`. Shop purchases and inventory fitting use `equipmentTransaction(_:)`, which takes a `Sendable` value intent and returns a typed applied receipt or refusal. There is no suspension between checking the request and publishing its result. The existing component and purchase engines remain pure value transactions; there is no second equipment owner.

The native view keeps the shop context only after painting its frame. Return wraps that context in a purchase intent. Selection clicks still only select a row or fitting. Pending navigation, a changed viewport, or a changed snapshot requires another paint before Return can buy. Inventory actions retain their existing painted-control checks and use the same actor entry point.

A shop context pins the complete commander, interaction epoch, selection, mount, work-tool choice, and displayed price. It creates no UUID or purchase history. The actor resolves the real catalogue offer and allocates transaction identities during the explicit purchase action. Every successful action advances the interaction epoch, including fuel and missile purchases that do not change physical equipment revisions. Replaying a captured intent therefore refuses; a fresh context after the commit permits a deliberate repeatable purchase.

Pause, screen changes, a new runtime, and successful load/startup restoration invalidate old interactions. Failed transactions and failed saves preserve the running commander and its interaction context. Invalid custody or a negative refill price cannot supply cash or fuel.

Recovered upgrades keep their existing full-source and physical component bindings. Normal flight does not invalidate an otherwise unchanged recovered upgrade. Ordinary fitting and storage require docking. Paid prerequisites, recovery receipts, acquisition provenance, and resource fractions remain with their existing transaction engines. Saving remains an explicit, separate action; a later save failure cannot undo or replay an already committed purchase.
