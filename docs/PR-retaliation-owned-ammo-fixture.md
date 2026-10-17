# test: establish valid empty ammunition for unlimited retaliation

The unlimited retaliation method now throws and stores the fixture’s three actual fitted rounds through normal Commander equipment transactions, reading the current revision for each transaction. It requires zero fitted rounds, zero mirrored missiles, a valid Commander, and successful equipment validation before enabling the original unlimited flag. See [the problem](ISSUE-retaliation-owned-ammo-fixture.md).

The shared fixture, production code, original loops, launch announcement counts, and final manual-disarm scenario are unchanged. Unlimited ammunition does not require an additional XYZZY provenance gate. Source formatting, Markdown lint, and whitespace checks cover this isolated change; focused execution and full validation remain pending with the canonical owner after run 222 closes. The exact caught error remains unobserved.
