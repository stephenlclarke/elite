# Match help scrolling hints to the actual viewport

System Data now says all rows are visible when its existing scroll window has no overflow. Inventory only advertises Option-Up/Down paging when its existing information window can scroll. The established six flight bindings, native/menu dispatch, persistent weapon selection and mission help remain unchanged.

Two deterministic `ContextControlHintUnitTests` methods cover overflowing/fully visible layouts at compact and wide widths, direct screen and Help-return contexts, retained Back/help hints, bounded help pagination and all six shared flight rows on every Inventory page. No simulation step, native journey or mutable input path is needed for this projection change.

Validation: strict Swift formatting/lint, all 20 Python report fixtures and diff checks pass. The agreed hosted selection includes both new methods, 257 total, preserving all prior methods. The branch includes the scoped workshop assertion correction for issue53. Swift compilation/execution and independent MBA review remain pending. No local Swift build, GUI, native/integration or broad quality campaign was run. No playable build or release is claimed. See the [issue](ISSUE-context-control-hints.md). Ledger M02.P01 / F04.
