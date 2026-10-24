# Combined contract summaries exceed Swift's type-checking budget

The first combined release-source compile at checkpoint 175 failed in `ContractBoardDisplay.swift` while type-checking the list-summary expression. The chained optional fallback combined reason, RRS, courier, pledge and ordinary offer formatting in one inferred expression. Renderer generation stopped before producing output.

## Required repair and acceptance

Give the existing RRS, pledge and ordinary offer subexpressions explicit optional String types, and the final summary an explicit String type. Preserve reason → RRS → courier → pledge → ordinary offer → `Unavailable` precedence, all displayed text and formatting, the existing preview-query order, row order and actions. No mission or transaction behavior should change.

Strict source lint and whitespace checks must pass, followed by the actual combined compiler and renderer retry under the coordinator's validation lease. The failed 175 attempt is not current media, test or release acceptance. See [the implementation handoff](PR-contract-summary-typechecking.md).
