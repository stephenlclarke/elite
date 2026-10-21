# Equipment display fixture carries Cobra stock into smaller hulls

The original combat-card and optional-work-tool display test selects the first hull with mining support and the first playable hull without it. Sorted catalogue definitions select SH023 Cobra Mk III (70 fuel, four missile pylons) and SH001 Adder (70 fuel, one missile pylon). The fixture changes the hull but carries the ordinary Cobra starting three missiles into physical equipment initialization, which correctly refuses the Adder with `invalidLegacyCount`.

Construct ordinary starting fuel and missile stock within the selected hull's actual capacities before equipment initialization. Preserve the original ship/tool selection, deterministic equipment identities and every UI, price and complete Commander-byte-conservation assertion. See [implementation](PR-ownership-display-starting-stock.md).
