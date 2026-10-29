# Hide unavailable contextual scrolling hints

Ledger M02.P01 / F04 already has one authority for W change weapon, Return fire, E ECM, Q release hold, Tab next target and F target filter. Native input, flight menu labels, generated help blocks and existing authority tests use those bindings. No input or weapon-selection rewrite is needed.

Two contextual hints remain inconsistent with their actual viewport: System Data always advertises scrolling, and Inventory always advertises Option-Up/Down paging, even when every row is visible. Use the existing System Data and information scroll windows to show those hints only when overflow exists. Keep all actual keys and unrelated mission/help content intact.

Acceptance: compact overflowing and tall fully visible windows produce the matching help, including when Help is open over the underlying screen. Retain contextual Back/help keys, bounded pagination and all six shared flight rows on every Inventory help page. Source/unit evidence does not claim native playable verification.
