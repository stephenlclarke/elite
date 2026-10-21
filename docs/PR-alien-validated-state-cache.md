# Resolve alien effects from an immutable validated witness

Adds a checked-Sendable final class containing only immutable values. Its initializer validates the complete normalized snapshot once, then builds per-hull counts and additive contribution totals using checked arithmetic. Queries return the four typed current summaries without replaying history; complete order-independent snapshot equality remains the stale-state authority, with no object-identity shortcut or unchecked Sendable assertion.

AlienAttachmentEffects gains a witness-based resolver and shares the original pure folding code with its existing ledger resolver. Only actual fitted physical instances contribute, retired/stored items are excluded and upgrade receipts increase contribution without increasing module count. The caller still supplies the resolved ordinary base, and the resolver rejects wrong owners, invalid bases and unrepresentable effective statistics. Resources are not refilled and native hull limits are not changed.

New tests cover actual normalized acquisition/upgrades/retirement/transfer, unchanged older witnesses, full semantic equality across record ordering and changed state, malformed source-history rejection, and concurrent read-only resolution under Swift 6 checked Sendable. Strict formatting, Markdown lint, exact folding extraction and source review precede compilation; focused tests are pending.

This is the cache/effects boundary for the upcoming native adapter. Commander does not yet store this witness, schema 27 hydration/publication is not implemented, and actual fitting/scoop authority remains with GameRuntime. These pure tests do not claim a real PLUGH fitting, native large save or live ship effect occurred.
