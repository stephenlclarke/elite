# feat(missions): retain native fixed-principal financial obligations

## Result and implementation

Declared `finance.offer` commands register a bounded independent offer without granting money. Finance rows in Station Contracts require explicit native Borrow/Decline or Repay review. Principal is granted once; repayment charges the lesser of real cash and remaining debt, carrying any remainder. Accepted records remain valid after parent completion/removal or provider loss. Their historical dock receipts retain owner/station/counter joins without requiring today's epoch or dock; live confirmation separately rechecks current sealed authority, writer, resources and review identity.

The existing private board review enum owns its finance variant and the existing immutable CommanderSnapshot. No Game UI slot, screen or letter shortcut is added. Back is the default; restored reviews reset to Back. Compatibility clicks with a nil generic offer cannot confirm finance. Overflow prevents Borrow while allowing an otherwise valid Decline. Normal credit commands retain their behaviour.

Paid and declined history remains readable without a writable save, current dock authority or installed parent content. Historical structural/resource validation still applies; history has no Borrow, Repay or Decline authority. A separate authored two-case regression reads exact terms/receipts, denies attempted transfers and conserves the full Commander and prior files with current dock evidence removed and no writer.

Finance lives only in the missions chunk and selects native schema 23. True pre-finance files have no liability; reserved finance fields are refused in older schemas, headers and raw Commander input. EMP state still selects 22 without finance, and all schema-before-22 EMP guards remain. Existing immutable chunks, hashes, pointer publication, startup first-publication receipts and Gallery namespaces own durability. Failed publication publishes no financial proposal.

## Authored verification and current limits

New regression definitions exercise genuine original-main doorway entry, quoted native Confirm, actual market purchase/sale funding partial/final repayment, declined/max-balance offers, stale/foreign/replayed input, parent completion and validated parent absence, exact source-dock ownership, native 21/22/23 compatibility, bounded decode rejection, actual blocked writers and prior-file conservation, plus isolated Gallery borrow/restart/return and denied writes to the live save.

This worker has not compiled, typechecked or executed any test or native app. Bounded parser/format/Markdown/data/diff checks are source checks only; focused execution, required full `make ci`, completed clean `@codex review` and final-head checks remain with G1 before protected merge. The feature is isolated after reviewed EMP dependency `64d26899618259541058c863049ee42e00262ffa`; only finance-owned commits should be integrated. No release readiness is claimed.

## Remaining requirements

The [problem](ISSUE-mission-finance-obligations.md) and [original example](mission-packs/finance-obligation/README.md) describe this generic profile. Historical GSE has different short/zero-payment closure and timing rules and is not delivered here. Interest, escrow, default/instalment scheduling, secondary finance facilities, content migration tooling and complete P04/P19 adaptation remain open. This first vertical slice does not complete the mission engine or R06 as a whole.
