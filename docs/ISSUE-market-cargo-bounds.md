# Keep purchases within supported cargo quantities

## Problem

A valid commander may hold up to `Int.max / 17` units of an individual commodity. Manual purchases checked tonne capacity but did not enforce the per-commodity bound for gold, platinum or gemstones. Buying one more unit could turn an accepted, savable commander into an invalid state. The market's availability label also used nominal capacity, so it could advertise a tonne purchase when actual fitted cabins restricted the trading hold.

## Acceptance

Refuse a purchase before changing cash, cargo or stock when the commodity quantity is already at the supported maximum. Allow the last supported unit and preserve ordinary selling. Show the same quantity and effective tonne-hold limits in market availability, including unlimited-cargo commanders with real fitted cabins.

## Validation

Exercise gold, platinum and gemstones through the real actor input, preserve the whole commander and market on refusal, and save/reload the maximum accepted quantity. Exercise four genuinely purchased cabins through the same actor purchase path and availability label. Full CI remains required before release.

See [the implementation](PR-market-cargo-bounds.md).
