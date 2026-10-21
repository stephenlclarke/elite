# Mission impact fixture reserves later Game copies during native launch

An unfiltered debugger probe of the exact full-run binary stopped in `__chkstk_darwin`, reached through native launch from `ledgerImpactFixture` and the original changed-source test. The separately observed debugger stop does not establish the cause of the earlier unobserved full-run signal.

The matching pre-edit object reserves seven Game-sized stack slots in the fixture and two in the observed caller before their next direct calls. Other original callers carrying later Game copies reserve two, one and four slots respectively. Preserve the real fixture producer and every original case and assertion while separating those lifetimes. See [implementation](PR-mission-ledger-fixture-lifetimes.md).
