# Navigation fixed-fit witness context

## Motivation

Eight navigation tests describe a stock 70-unit tank and seven-LY native fit but inherit the current SH025 starter's 130-unit tank and nine-LY reach. This changes full-refill cost, planning scope and legal hops. In particular the current Avenor-to-Enmadan link is about 8.783 LY, so the deliberately invalid `[7, 0]` leg becomes legal for SH025.

## Correction and acceptance

Select the actual SH023 hull before any owned inventory or native world exists, initialize its stock fuel, energy and shields, and require valid seven-LY context. The paid-upgrade method requests this same hull without a preinstalled navigation computer; the other methods retain their existing military computer setup.

Preserve all seven/fourteen/twenty-one-LY scopes, 70-unit fuel, 140/139-decicredit funding thresholds, price and technology checks, legal hops, unique paths, stable estimates, route progress, save/load and no-free-fuel assertions. Qualify all eight methods together because they share the changed helper. No production or default change is included. Companion: [PR-navigation-stock-hull-fixture.md](PR-navigation-stock-hull-fixture.md).
