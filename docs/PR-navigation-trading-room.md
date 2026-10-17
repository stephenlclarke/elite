# Respect reserved cargo space in navigation trade estimates

## Change

Navigation now subtracts ordinary sellable tonne cargo from occupied tonnage to derive the space that remains reserved. Tonne trade estimates use effective trade capacity minus that reservation; non-tonne estimates retain the market's 63-unit quantity bound without consuming tonne room. For example, one fitted five-tonne cabin in the default twenty-tonne hold limits a tonne opportunity to fifteen units, including under unlimited cargo policy.

All arithmetic for estimated tonnage uses finite Double conversions and accumulation. Existing cargo-sale custody checks, route ordering, fuel checks and trading mutations are unchanged.

## Validation

Strict Swift formatting and whitespace checks passed. Nine new test cases cover actual cabin purchase/fitting and the real buy limit, a full four-cabin hold refusing tonne purchases, saved marked-firearm custody, actual scripted-courier payload acceptance, real salvage release/collection, an ordinary full hold whose contents may be sold, a non-tonne purchase while full, and maximum accepted tonnage. Each scoring case checks full Commander conservation. Compilation, test execution, coverage and release gates remain pending central validation; no runtime result is claimed here.

## Compatibility and limits

No save format, equipment, custody, route state or monetary API changes. Estimates remain planning opportunities rather than promises about future market stock, sale prices or available cash.

See [the issue](ISSUE-navigation-trading-room.md).
