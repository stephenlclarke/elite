# Native Return proof and mining module fixture failures

Run 475 recorded four assertion issues in two control/mining methods before a later unrelated EMP archive crash. These are actual recorded failures, not qualification of the wider cohort's outcomes.

The manual-mining test expected `.targetingMining` to be fitted by its maximum-hardware legacy-set fixture. Native initialization deliberately preserves unrepresented specialty modules as held owned items. The fixture owns the module but has not fitted it, so the test stopped before reaching manual tracking.

The native Return test expected raw `return` queue entries from an unpainted view. `GameView.keyDown` records held input first, then the maintained proof boundary refuses to enqueue an unpainted protected command. After genuine painting, Return queues an encoded `script-page-key` packet containing the painted absence/presence proof. The raw-token expectation also disagrees with that representation.

The fix must use actual owned fitting/store operations and actual painted proof/event processing, retaining manual tracking without a work hold, Return/keypad held-fire semantics, fresh presses after interruption and stale-repeat/context protection. It must preserve the production proof boundary rather than bypass it.
