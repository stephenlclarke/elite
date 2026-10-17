# Install modular hyperspace drives and preserve legacy inventories

Each hull receives a real owned Basic drive. Intermediate costs 5,000 CR at displayed
tech level 10; Advanced costs 15,000 CR at level 13. Fitted and paid prerequisites apply.
Actual H travel resolves 10, 5 or 1 seconds multiplied by the navigation ratio once.
Ship and celestial hyperspace mass lock scales to 100%, 80% or 60%; in-system safety,
finite fuel and navigation range remain separate. XYZZY grants Advanced.

Equipment versions 1 and 2 migrate explicitly to version 3. The complete preparation
transaction publishes finite ammunition and the stock drive together. UUIDs, original
items, paid history, cargo and balances survive. One validated born-stock drive has a
reserved migration place beside the unchanged ordinary 256-item pool; earned promotion
and storage retain that identity. Extra ordinary items and duplicate foundations refuse.

Save publication establishes the existing calendar boundary, preserves an untracked
legacy jump marker when necessary, and uses version 25 or a later composed version.
Older/raw headers reject modern drive state. Player help, status and inventory display
actual drive and navigation values without changing the original catalogue records.

Source formatting, scoped Markdown lint and whitespace checks pass. Authored tests cover
physical stock, real shop debit, H travel/fuel, in-system safety, save/downgrade, full-pool
migration, progression and authentic version-1 ammunition migration with atomic failure.
Execution, native acceptance and full CI remain pending. Pure profile tests previously
passed validation 254; that result alone does not validate the new runtime.

Alien immediate travel remains a typed integration foundation requiring actual owned
salvage and authenticated PLUGH fitting. See [migration details](MODULAR-HYPERSPACE-DRIVES.md)
and [motivation](ISSUE-hyperspace-drive-profiles.md).
