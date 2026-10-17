# Add normalized alien storage and bounded content-addressed pages

Adds six typed indices for world history, immutable collected sources, physical
attachments, owned upgrades, receipts and commands. Upgrade application and large
hull transfers use independent receipt records instead of growing per-item or
per-command arrays. Full chronological replay validates final ownership and effects.

World records preserve original plans, seed and source facts, EMPTY/nonreserved
outcomes, monotone work/depletion/destruction and individual reserved-lot custody.
The compact progress header mirrors the native allocator: original item quantities,
discard flags, structural material and next lot number. Arrays have exactly the
immutable original plan's item count. Checked prefix reconstruction compares actual
issued evidence with the original item rebound to its authentic allocated identity.

The codec writes bounded leaves and a multi-level index with a fixed six-root header.
It imposes no lifetime record, page-count or tree-depth limit. Decoding checks canonical
encoding, ownership, hashes, key order, counts, ranges, page aliasing and all typed
joins. Snapshot equality ignores caller insertion order. Transitions reject history
deletion, source rerolls, retired-item revival, applied-upgrade reuse and custody rewind.

The file store stages immutable pages and root bytes. Directory descriptors anchored
from `/` and no-follow component opens reject links in ancestors and page paths.
Existing authenticated pages are synced again before reuse, covering interrupted
writes that left complete but unsynced orphan files. Errors propagate to the save
owner. Whole-generation publication and its atomic native pointer remain integration
responsibilities. Callers must supply a canonical directory path without symlink
ancestors; for example resolve the system temporary directory before using it.

## Validation supplied

New tests cover cross-page transfers, unapplied upgrades, retirement, order-independent
hashes, more than 16,384 upgrades on one physical attachment, total page data beyond
4 MiB, malformed authenticated pages, missing/corrupt pages, owner mismatch, permanent
claims, every page-write failure and immutable/no-symlink file-store behavior. Real
salvage-producer fixtures exercise structural-before-alien issuance and mixed commodity
chunks before technology, using genuine retained progress rather than fabricated IDs.
World tests cover pending offers/bindings, monotone terminal custody and EMPTY plans.

Formatting, scoped Markdown lint and whitespace checks are the local checks. Compilation,
test execution, native save/restore, fault injection against final publication and
`make ci` remain for the main coder; passing execution is not claimed by this source handoff.

## Integration contract and limits

- The actor owns original inspection, work, shared allocation, producer permits,
  collection revisions and admission. Alien world/ownership must bypass ordinary
  lifetime pools before inspection and work as well as collection.
- Native migration must use genuinely retained validated original progress and actual
  lot evidence. Ambiguous or insufficient evidence fails atomically while preserving
  original bytes; it cannot manufacture missing history.
- The actor supplies current authenticated dock authority for PLUGH and performs live
  effects once per fitted attachment. This package does not grant recovery or dock rights.
- The save owner writes a small `AlienStorageReference`, stages the complete versioned
  generation, validates its cross-chunk joins and publishes the final pointer atomically.
  `previous: nil` means first history only; subsequent staging supplies the prior snapshot.
- This implementation materializes normalized records in memory and sorts/replays them.
  It is not a bounded-memory streaming database. Memory, disk, I/O and representable
  arithmetic limits still produce real failures. Existing per-source UInt16 lot IDs
  remain the native collision domain; no new total-plan/history cap is introduced.
