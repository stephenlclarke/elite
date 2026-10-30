# fix(equipment): use approved original stock prices and technology

## Change

Original equipment offers now use the approved thirteen non-Fuel CR prices and fourteen one-based technology values. `Equipment.requiredTechnologyLevel` retains its existing stored-value-plus-one encoding. Fuel's existing price and the two already matching TL values are retained. The only PLUGH pricing change removes the stale Naval Energy override so the existing adapter discounts the authoritative 196,000-tenths stock price once, giving 147,000 tenths. Reward overrides for other items, actual service/acquisition/fit gates and paid prerequisite rules remain intact.

The implementation is an additive successor to `4e1bd50f9261bb603cf0fe05946f9f4e454ab6b3`. It imports no C03 or archival geometry work and does not replace the later M02 Liberator fixture correction. G3 will port the reserved numeric hunks into its coherent identity change. The shared price/technology and transaction adapters retain their existing behavior; no new runtime catalogue, grant, migration or price policy is added.

## Dependent finite scenarios

The existing G03 preparation pins the actual paid Extra Energy quote and total. These guards now require 72,000 and 143,000 native tenths. Both maintained Gallery manifests and the shared controlled simulation initializer start at 157,000, preserving the 14,000 post-fit budget. The explicit escape-pod fixture starts at 183,000 and pays 36,000 for that pod, preserving its 4,000 remainder. The insufficient-budget test moves to 142,999 and still requires whole-operation refusal. Pack scripts, versions and the frozen legacy-v1 fixture remain unchanged; the two current manifest digests change solely because of their declared trial budgets. No maintained generator for these two manifests exists in this repository.

Existing tests change only directly superseded price/balance/TL expectations and the finite setup needed for their original positive path. The Elite energy shop selects technology high enough for the newly TL17 Advanced predecessor even though Elite itself remains TL14. The small purchase sequence uses a finite 200-CR budget and a real shop supporting its newly TL4 cargo bay. Targeting's independent prices remain 800/12,000 CR; its old laser-relative assertions and stale source comment are corrected without changing its price or technology code. Player documentation updates the two energy prices and Advanced TL while retaining the actual strength ratios.

## Focused verification

`OriginalEquipmentStockValuesTests` authors six methods/seven cases. It checks all fourteen authenticated rows, both ordinary and PLUGH transactions for all thirteen non-Fuel items, exact debit and paid receipts, retained item identities/resources, reachable original-world technology refusals, stale old-price refusal, finite cash and missing-predecessor refusal, and unchanged alien acquisition gates. Naval PLUGH must quote and charge 147,000 tenths. Fuel still charges its existing two-tenths supply-unit price and rounds the three-unit PLUGH refill once to five tenths. Low TL encoding is checked directly because the current galaxy's installed worlds start at TL4; no synthetic original world is created.

MBA found that the current procurement pack digest also changes its derived board seed and six draws. The current-content golden now pins the new seed, initial state, six draws and final state. Static SHA256/xorshift reproduction first matched every old value, then derived the replacements; no generator or candidate-order rule changes. The separate legacy-v1 goldens and the freight test's explicitly supplied independent seeds remain unchanged.

The new methods and changed existing methods are UNRUN. Standalone Swift formatting/parser lint, scoped Markdown lint and source/hash/arithmetic checks are author-side static evidence only. G1 owns focused execution and later required integration/CI/leak gates. MBA review of the frozen packet and the eventual coherent PR remains required. No author compiler, test runner, native/GUI/GPU, renderer, probe or CI execution is performed.

## Compatibility and remaining risks

Existing equipment, grade thresholds, immutable upgrade origins, grandfathered strength, alien multipliers, reward rights, save schemas and paid receipt semantics are untouched. Original Fuel units, energy/progression precedence and laser cadence remain open. Separate combat-cost work is outside this packet. This source-only slice does not establish playable M03 delivery or close all U03. See the [issue](ISSUE-original-equipment-stock-values.md).
