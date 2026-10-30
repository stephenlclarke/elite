# Keep original market quote identity independent of source array order

The original catalogue validates a complete unique set of seventeen commodity IDs. It does not require quotes to appear in ID order. Its indexed lookup already resolves the explicit quote ID, but the live seed adapter previously copied the source sequence into commodity-indexed arrays. A valid reversed or permuted state would therefore assign another commodity's prices and stock to each affected slot.

All 2,048 currently bundled states were inspected and already have canonical ID order. This is an accepted-schema/consumer join mismatch, not a claim of current resource corruption. Preserve the authenticated resource bytes, schema, authored source order and separate market display order. Canonicalize only the live seed projection by quote ID.

Scope is the pure adapter in OriginalLiveMarkets, three deterministic source-authored methods, this note pair and the necessary README paragraph. No Game, transaction, save, commodity ID, numeric balance, price policy, pin, resource, selector or CI changes are included. [Implementation and validation limits](PR-original-market-quote-index-join.md).
