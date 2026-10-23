# Equipment purchase and migration frame lifetimes

The retained required-quality run39980129381 at e2f0498c (synthetic88f9413b)
failed coverage-check after887.35s compilation; make ci exited2 after
1786.012624s. The helper reported signal10. All171 media entries passed;
thread/address sanitizer and leak stages were not reached.

Owned capture PID32407/thread4 reaches stack probing with LR in
EquipmentModuleTemplates.legacyMapping, through migratedComponent,
initializeEquipment, preparation/migration, quoteEquipmentPurchase,
performShopPurchase and the original four-mount replacement test. The matched
image UUID beginsC4D3B4B4. Evidence is retained at
`/tmp/elite-mba-e2-quality39980129381`. No mapping semantic defect is inferred.

The internal purchase quote now stores exactly the same immutable full source
and prepared Commander snapshots in a final Sendable class. Its binding and
request fields remain unchanged. Detailed quote/request construction occurs
only after equipment preparation returns. migratedComponent is static because
its unchanged implementation reads no Commander; its three production callers
and one pre-drive fixture caller use that entry. The unrelated fuel candidate
is confined to its own noninline branch helper, retaining exact checks, debit,
trade history, validation, publication and receipt order.

No mapping, selected mount, price/cash, quantity, save schema, actor isolation
or atomic publication/rollback rule changes. Existing immutable quote consumers
still compare the complete source and retain independent Commander values.

Focused execution retains five existing methods and ten cases: original
four-mount replacement(one), stale commander/offer(six), legacy bag migration
(one), actual purchase writer rollback(one), and concurrent fuel/missile intent
(one). All original assertions remain. Execution is pending; full524, required
quality, native M01 and release qualification remain separate. The unresolved
VM SIGILL in144 is not claimed repaired by this source-backed correction.
