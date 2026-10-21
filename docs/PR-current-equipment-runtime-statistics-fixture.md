# test(equipment): inject an actual unsafe effective fuel statistic

The `runtime-statistics` case now sets the existing fitted navigation component's fuel-cost multiplier to `1e16`, preserving item/component identity, origin, grade, features, receipts, provenance, location and inventory revision. It verifies the multiplier is effective and that the finite loaded component passes ordinary inventory validation. The existing effective runtime guard rejects its out-of-Int-range fuel cost.

This replaces an ineffective assignment to the legacy storage-count backing field, which current inventory-derived `fuelStorageUnits` correctly ignores. Production validation, valid upgraded/grandfathered values and migration semantics are unchanged. The original case name, both expected refusals, zero migration allocations and complete Commander rollback checks remain; no new IDs, ticks or test method are added.

## Validation

Strict Swift formatting, paired Markdown lint and whitespace are source checks. No compiler, tests, probes, native, GUI or debugger jobs were run here, and no new runtime pass is claimed. G1 will review once and integrate at the safe closure of its frozen wave, batching this with other necessary repairs. Only the failing method/case needs focused validation before final required gates; the seven accepted equipment methods remain retained.
