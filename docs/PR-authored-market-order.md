# Apply authored market order and original night technology

Market rows used commodity-ID order instead of the authored sequence, while original-world night lighting clamped levels16-19 to the legacy maximum15. This PR combines those two independently qualified corrections after their necessary shared test-selection conflicts. Inventory and contextual help are already merged in the base.

Market rendering, row clicks and only the reserved market Up/Down branches now share one authored display-ID projection. Selection stays the stable commodity ID, including Food0, and retains bounded endpoints and Buy/Sell/redraw behavior. Cargo and quote arrays, quantities, prices, transaction authority and unresolved U03 numeric precedence remain unchanged.

Original-world night profiles use the catalogue's authored technology bounds1-20. Explicit legacy profiles keep their existing0-15 coefficients. Day appearance, economy/government coefficients, identity, materials, geometry, thermal and rendering backends are unchanged. The imported production code and tests are byte-identical to the qualified night PR58 head.

The final selector is the exact267-method union of the merged261-method inventory/help base, three market methods and three night methods. Static source comparison preserves every method and the independently qualified domain files. The three MarketDisplayOrderUnitTests cover all17 IDs, keyboard navigation and render/click identity at compact/wide sizes without trading. The three PlanetNightTechnologyUnitTests cover2048 worlds, actual16-19 levels, matched1/20 endpoints and unchanged legacy behavior. Their endpoint records are presentation fixtures, not published worlds.

Prior independent final-head evidence remains: market5da5ae1a and nightfa280963 each passed260 methods/292 cases; the merged inventory85e67590 passed261/293. These do not claim execution of the new267-method composition. Strict Swift formatting/lint, all20 Python report fixtures, Markdown lint and diff checks pass; the final hosted execution and MBA composition review are pending. No local Swift/native/GUI/integration, media or visual/performance campaign was run. No new usable build or release is claimed.

See the [market issue](ISSUE-authored-market-order.md) and [night-technology issue](ISSUE-original-night-technology.md). Ledger M03.P03/F10 and M06.P03/F19. After this complete composition merges, PR58 can close as superseded once its changed source/tests and selector additions are proved included.
