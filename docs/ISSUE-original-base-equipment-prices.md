# M03.P03 / U03: approved base prices disagree with the actual equipment shop

The bundled original authoring retains fourteen proposed equipment prices, but the actual Equipment.base table still uses predecessor prices. Shop rendering, purchase quotes, fuel refill and committed debits consistently use that runtime table, so bundling authoring alone did not apply the intended economy.

On 24 October 2026 Root explicitly adopted twelve non-energy proposal prices as the current design resolution. The proposal labels itself private/not installed; this is a new adoption decision, not a claim that the proposal was already authoritative implemented behavior. Later energy-module stock values supersede the two proposed energy prices. Preserve current fuel quantity semantics, once-per-refill PLUGH discount, reward access, technology levels, damage, recharge, stock, cabin/module prices, state and save schema.

Scope is twelve exact Equipment.base price initializers, actual quote/readout/debit/refusal regressions, directly affected test price oracles and documentation. Ordinary shield prices already derive from their named lasers at three quarters; retain that join rather than add a second price authority. No production transaction or simulation rewrite is needed. Full M03 playable acceptance, technology alignment and damage rules remain separate work.
