# Original stock equipment prices and technology still use superseded values

## Problem and authority

The human-approved original-world handoff makes its versioned equipment dataset authoritative and requires replacement of superseded price tables. The imported authoring file contains 14 original equipment rows. Its verified SHA256 is `47d83caae5a9b22a4a932f19c55f79c5cb5435b962826a0969ece096b11f80eb`. Thirteen ordinary stock prices and twelve displayed technology requirements still differ from those rows. Fuel TL1 and Extra Energy TL9 already match. Naval Energy lives in `Equipment.all`, and its old PLUGH override would also mask the corrected stock price.

Root assigned this isolated M03 price/TL slice from `4e1bd50f9261bb603cf0fe05946f9f4e454ab6b3`. It is separate from G3's identity rename and the live M02 qualification. See the [PR notes](PR-original-equipment-stock-values.md).

## Required behavior

Use the original CR prices for all thirteen non-Fuel stock items and encode all fourteen original one-based TL values through the existing zero-based equipment field. Keep the original typed identities, actual station services, acquisition rights, physical fit, paid prerequisites, finite debit and once-only PLUGH discount. Naval Energy costs 19,600 CR ordinarily and 14,700 CR at PLUGH, with no duplicated stock-price override.

The G03 paid preparation must use the same new Extra Energy price. Its five-item fit rises from 86,000 to 143,000 native tenths. Its controlled Gallery and simulation starts therefore rise from 100,000 to 157,000 tenths to preserve the original 14,000 remainder. The explicit escape-pod test start uses 183,000 tenths, pays the new 36,000 pod price and retains its original 4,000 remainder. These are fresh controlled scenarios; they do not fund or reset a current player. Preserve failed-purchase atomicity and actual paid receipts.

## Remaining scope and validation

Fuel's authored 1.8 CR has no denominator, so its existing supply-unit price remains unchanged. Combat costs, laser cadence, energy/grade progression and alien effects are separate decisions or assignments. No stock-price change may reset existing item strength, upgrades, provenance, resources or receipts. U03 is not complete through this slice.

The focused tests must bind the authenticated original rows to actual offers, debit and receipts, check PLUGH pricing and refusals, and retain service, prerequisite, cash and custody assertions. Author-side compiler/native execution is prohibited by the current executor lease. G1 owns execution; authored tests remain UNRUN and this packet remains in validation pending until they pass and MBA closes its review.
