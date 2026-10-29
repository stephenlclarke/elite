# C08.P03.A: service and return the original workshop cassette

After stage 4, the original failed Enmadan cassette occupies one mission tonne. Stage 5 requires Renas's repair desk to record completed service of that same serial and its owner's receipt. A visit, replacement commodity or generic completion flag cannot close the loop.

Reuse the existing closed native repair-condition transition and preserve clinic reception, workshop ownership and original serial. Commit service and owner return together at the actual Renas main berth, release the reservation once and refuse stale/duplicate/lost/foreign-unit claims. This child precedes the separately queued C08.P03.B consented vault-key loan. See the [completion ledger](COMPLETION-LEDGER.md) and [implementation details](PR-exchange-cassette-service.md).
