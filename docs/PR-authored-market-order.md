# Use authored commodity order throughout the market

Market rows now follow the authored 17-commodity sequence through one pure display-ID projection. Rendering, pointer rows and the two reserved market Up/Down branches use the same mapping. Selection remains the stable commodity ID, including Food at ID0, so redraw and Buy/Sell changes preserve the selected commodity. Up/Down retains the existing bounded first/last behavior.

Three `MarketDisplayOrderUnitTests` methods verify the exact authored sequence without changing cargo indices, every arrow transition in Buy/Sell/Prices modes without trading, and render/click agreement for every stable ID at compact, wide and fully visible layouts. Original Commander property and live stock remain equal through these projection/selection operations.

Only the market selection branches in Game change; no simulation, mission, cargo/save mutation or transaction authority changes. Numeric prices, stock quantities, equipment mechanics and U03 precedence remain unchanged. The ordinary cargo/quote arrays stay in stable ID order.

Validation: strict Swift formatting/lint, all 20 Python report-validation fixtures and diff checks pass. The agreed hosted selection includes all three new methods, 258 total with all previous methods retained. The separately authored issue53 correction is composed. Hosted Swift execution and independent MBA review remain pending. No local Swift build, native journey, GUI, integration or broad quality campaign was run. No usable-build/release claim. See the [issue](ISSUE-authored-market-order.md). Ledger M03.P03 / F10.
