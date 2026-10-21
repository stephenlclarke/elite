# Unsupported recovered-tool fixture exceeds its hull's missile capacity

The original unsupported-slot test selects the first playable hull without salvage-cutter support: SH001 Adder, whose native definition has 70 fuel units and one missile pylon. Changing only the hull leaves the default Cobra's three missiles in the fixture, so correct physical equipment initialization refuses with `invalidLegacyCount` before the intended recovered-device assertions.

Construct legitimate ordinary starting stock before initialization while retaining the actual selected unsupported hull and the original occupied-device and complete Commander-conservation checks. See [implementation](PR-recovered-feature-starting-stock.md).
