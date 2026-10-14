# Ship definitions and generation

Every catalogue record lives in one authoritative, self-contained [TOML file](../Sources/EliteCore/Resources/Ships), named by its stable `SHnnn` save ID. The folder contains 167 definitions: 158 flyable project adaptations and nine display objects. The initial Cobra uses the same loader. SwiftPM copies the complete folder into the app resource bundle; development and packaged builds both decode it with pinned [TOMLDecoder 0.4.5](https://github.com/dduan/TOMLDecoder/tree/0.4.5). Invalid geometry, gameplay ranges, IDs or filenames fail loading explicitly. There is no separately maintained JSON catalogue or model pool.

Top-level fields retain identity, class, editions, evidence, model association and dimensional context. `[game]` contains authoritative native gameplay and price values; its absence means the object cannot be flown. `[design]` contains the actual vertices/faces, source and licence. Its inline `custody` table preserves original model hashes, source definition, components and archive/file dependencies. Original project designs also retain an authoring recipe. `[[profiles]]` retains every source/refit field, unit, status and basis; these are inspectable source facts and do not override `[game]`.

## Game conversion

Initial native values use each common project refit's ratio to the same Cobra Mk III refit, multiplied by the established native Cobra value. The anchors are speed 350 to 32 cockpit speed, acceleration 160 to 12 speed/second, energy 256 to 256, energy recharge 4 to 2/second, shields 128 to 255, shield recharge 2 to 1/second, roll 2 to 1 radian/second and pitch/yaw 1 to 1 radian/second. These are project calibrations, not physical SI conversions or historical measurements. The resulting values are maintained explicitly in each TOML and used directly by flight and the showroom.

Cargo tonnes, fuel tenths of a light-year, jump light-years, charging seconds, missile pylons and laser facing masks retain their common-refit meanings. All hulls with a standard hold of at least 20t support the native 15t Large Cargo Bay; smaller hulls retain their explicit TOML fitting allowance. This is an intentional project fitting adaptation. Other paid modules transfer universally; laser mounts, missile racks, cargo and fuel capacities are enforced. The source-only equipment slot pool is not a native fitting counter. All playable hulls use solo automation rather than pretending the game implements a hired-crew system. Source crew complements remain in the reference appendix.

Ships use the native point-based collision/docking system and the same normalised visual envelope; source dimensions do not turn a capital ship into a full-scale physical docking simulation. The player flies from the cockpit; the owned hull's actual model appears in its showroom view. Original encounter variants also load from the same ship TOMLs: optional `nativeHull`, `[nativeDesign]` and `[nativeCombat]` retain the original NPC blueprints and mission combat values separately from the player adaptation. Independent geometry digests preserve their original coordinates, winding and wire details. Non-ship projectile/cargo/asteroid primitives remain renderer geometry.

The showroom compares both hulls with the same carried equipment and XYZZY policies. It uses the current hull as the initial baseline; pinning selects another hull with that same fit. Unlimited cargo is a policy, not an enormous numeric bay; the separate Fitted hold row keeps physical capacity comparable even in XYZZY. Fuel supply does not remove tank/navigation limits. Navigation computers increase the hull's base jump cap when their limit is greater; usable range is still limited by actual fuel. Green **BETTER**, orange **WORSE** and cyan **SAME** describe the selected value. Lower hull price and charging time are better; greater capacity/performance is better. Unknown values display `?`, not an equality claim. The displayed tenth-unit precision governs equality. Source mode retains original units and only subtracts compatible profiles.

## Economics and power sorting

Prices are chosen project economics, not historical Elite prices. The Cobra is anchored at 150,000 CR. Initial prices are rounded to the nearest 1,000 CR, with a 5,000 CR floor, using:

```text
150000 * (0.30 * speed/32 + 0.25 * energy/256
        + 0.35 * (cargo+20)/40 + 0.10 * missilePylons/4)
```

The actual editable result is the TOML `game.price` in credits. Commander accounts store tenths of a credit. Trade-in is 75% of the owned hull's current listed price; equipment transfers rather than being sold or credited. There is no free stock or refuel on exchange. The quote shows gross price, allowance, net cost/credit, resulting balance and compatibility before confirmation. Back is selected initially. Insufficient funds, oversized cargo (including reserved mission cargo), unsupported paid mounts/bay, excess fuel/missiles and incompatible active routes block the exchange without loss. Compatible mission state and property persist unchanged. XYZZY follows the same exchange rules; its existing cash policy is respected.

Power sorting uses the native standard hull index `energy + 2*shield + 32*recharge + 64*missilePylons + 128*laserMountCount`, strongest first. It is a project capability index, not a historical rating, installed weapon damage or crew count. Alphabetical sorting is A-Z; display name and stable ID break ties. Filters and selection survive sorting. Non-flyable objects follow ships in Power order.

## Update workflow

Edit the corresponding TOML, then run:

```sh
make ships
make ships-check
make ci
```

`make ships` reads the same folder as the game. It renders changed ships first, then generates [the central catalogue](SHIP-CATALOGUE.md) and [source/design appendix](SHIP-PROVENANCE.md). Each GIF has an explicit content-hash dependency on its entire TOML (including geometry), shared simulation/rendering Swift sources, pinned dependencies and render settings. The checked-in manifest also hashes the output, so missing/corrupt images rebuild. Unchanged inputs reuse their GIFs. A shared renderer change invalidates all affected animations. Paths and hashes contain no machine-specific absolute paths. `make ships-check` rejects stale GIFs or Markdown and runs in CI. `make showroom-data` is an alias of `make ships`.

The 256-square, 24-frame shaded animations use the actual game projection and renderer. They rotate once every 2.4 seconds and loop. The complete collection is about 9 MB. README media still uses `make readme-media` exclusively.

`make showroom-import SHOWROOM_MODELS=... SHOWROOM_EXPANSIONS=... SHOWROOM_MODEL_CACHE=...` stages newly verified research output in ignored `reports/showroom-import`; it does not replace maintained TOMLs. Review source changes and update the selected TOML's source profiles/design/custody while preserving its game values and stable ID. The importer retains its source hash and full-assembly checks. Normal builds and media generation require no research checkout or source archive cache.
