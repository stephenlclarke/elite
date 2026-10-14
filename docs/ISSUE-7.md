# Issue: make controls, comparisons and ship exchange usable

Players could not reliably tell which keys were active: the status screen advertised scrolling even when all rows fit, search consumed navigation inconsistently, and Escape had unsafe or surprising meanings. The showroom mixed source-engine pools with native fitted values, had missing models, and could not exchange the player hull.

The requested outcome is a small MacBook-friendly control vocabulary, context-correct hints/help, actual buy/fly/trade behaviour, comparable native specifications, complete visuals, and one authoritative TOML per ship containing its specs and design. The game, incremental rotating GIFs and central Markdown catalogue must use those same definitions. Last-save restoration and XYZZY legal reset are included.

Acceptance: numbers/arrows/Return/Escape/K and visible secondary actions work in context; transactions preserve cargo/equipment/mission property; ownership and legal state survive save/load; every catalogue entry has a rotating model/reference; changed TOMLs invalidate their own GIFs; unchanged ships reuse media unless shared rendering changes. Required coverage, sanitizer, leak and protected-main Sonar gates remain in force.

Linked implementation: [PR #7](https://github.com/stephenlclarke/elite/pull/7), [ship schema and limits](SHIP-FILES.md), [controls](CONTROLS.md).
