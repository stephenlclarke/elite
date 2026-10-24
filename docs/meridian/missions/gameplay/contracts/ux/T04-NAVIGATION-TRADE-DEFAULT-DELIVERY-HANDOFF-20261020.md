# T04 navigation-and-trade practice: default delivery handoff

Prepared 20 October 2026 for Root approval and the next MBA assignment after G13
integration. One existing ledger item, no implementation or execution. M01
remains first. Other queued producer-dependent items remain parked.

## Recommended outcome and source

**T04 / M05 / F36**, `l337.training/navigation-trade`: a normal player receives
the existing original trade tutorial with the app, finds it through Mission
Contacts/Gallery, buys one actual tonne, flies the selected route, sells it at
the selected destination and returns to the real issuing berth. The lesson
reports real fuel/cash/profit or loss and grants its own clue only at true
training reception. No tutorial payment, invented profit, deadline or new
controls.

The approved original design is the exact `l337.training/navigation-trade`
template in `original-missions/original-families.json` and its Markdown
counterpart. One cargo tonne, zero berths/deposit/reward; clue
`navigation-trade-family-trace`.

Narrow source inspection used canonical
`f1a0a5310b5613867eb14cb184506aecdd53d987` while G13 was entering integration.
G1 selects the actual final integrated G13 base. This observed snapshot is not a
G13 integration-completion claim.

## Source-confirmed readiness and actual gap

- Existing executable pack: `docs/mission-packs/l337-navigation-trade/` contains
  manifest.toml, scripts/main.lua and README.md. The manifest already has
  original dialogue, fitting/route confirmation, real trade, cancellation,
  actual reception and loss handling.
- `ScriptNavigationTradeContent.swift` pins version 1.0.0 and exact digest
  `8c23ce72936e8bdfa47978f7d7d4240171babe05c2da5ac49727d2616e38d802`. Its
  production clue pin is already installed. Preserve these bytes and the pin.
- `ScriptNavigationTradeBinding.production/selectedRoute` in
  `ScriptNavigationTradeState.swift` resolves actual installed original worlds;
  it is not limited to injected test bindings.
- `ScriptDirector.scriptUnavailable` already calls the production binding. Its
  actual command dispatch selects production retained/selected endpoints. No
  Director activation hook is missing.
- `ScriptNavigationTradeRuntime.swift` already provides actual
  fitting/contact/market/travel/fuel/reception/loss evidence.
  `ScriptNavigationTradeSave` and the current writer already validate the state.
  Existing ScriptNavigationTradeTests cover accounting, current reload and
  filesystem rollback, but this handoff claims no fresh execution.
- The exact delivery gap: ScriptBundledPacks.defaultLibrary currently includes
  the other production providers but omits T04; the pack exists only under
  documentation, absent from bundled resources. Current unavailable text says
  endpoint bindings await installation even when the player merely has no
  distinct destination selected.

This is a default-content/usable-entry gap, not a request to rewrite T04, add a
new provider or claim all tutorials complete. The first courier inspected
instead needs untimed-profile/custody changes, so it is not chosen for this
smaller disjoint batch. No wider queue inspection is needed.

## Exact proposed 9-path ownership

Root grants the bounded paths before source edits. **MBA/G3 owns 8 paths; G1
owns 1 current shared loader hunk; G2 independently reviews the qualified
complete boundary.** G1 integrates after owner-focused PASS. The split avoids
concurrent editing of G13's shared loader.

MBA/G3:

1. `Sources/EliteCore/ScriptNavigationTradeRuntime.swift`: ONLY
   navigationTradeUnavailable's refusal text/classification for exact approved
   T04. Distinguish missing original endpoints/content from no distinct selected
   chart destination; give the actual next player action. Preserve every
   binding/admission check and command implementation.
2. NEW `Resources/ScriptPacks/l337-navigation-trade/manifest.toml`, relative to
   `Sources/EliteCore/`: byte-identical copy of the existing approved
   documentation pack file.
3. NEW `Resources/ScriptPacks/l337-navigation-trade/scripts/main.lua`, same
   Core-relative root: byte-identical copy.
4. NEW `Resources/ScriptPacks/l337-navigation-trade/README.md`, same
   Core-relative root: preserve the existing pack file so copied package content
   stays exact.
5. NEW `Tests/EliteCoreTests/OriginalNavigationTradeDeliveryTests.swift`: actual
   bundled/default-library/ordinary UI discovery and production-binding flow,
   plus refusal/safety cases.
6. `Tests/EliteCoreTests/BundledScriptPackTests.swift`: only directly affected
   default-provider and digest-dedup expectations.
7. NEW `docs/ISSUE-original-navigation-trade-delivery.md`.
8. NEW `docs/PR-original-navigation-trade-delivery.md`.

G1 sole central loader path:

- **Path9:** `Sources/EliteCore/ScriptBundledPacks.swift`: exact bundled T04
  directory and defaultLibrary append/catch/digest-dedup branch, composed after
  G13 integration. No other loader refactor or provider-order rewrite.

No `ScriptMissionState`, Game, Director, market/equipment mutation,
ScriptPersistence/preflight/schema, clue-catalog/journal, current G13
transaction or offer-policy edit is proposed. All T04 execution providers remain
unchanged. The only shared current-G13 file is the isolated G1 loader hunk
above. Any demonstrated extra path returns to Root for exact reservation before
edits.

## Focused owner acceptance

1. Native loader reads the bundled copy with EXACT current
   version/digest/capability and existing production clue pin. Default library
   includes exactly one identical tutorial when also installed in the user
   directory; missing/malformed bundled resource follows existing truthful error
   handling without hiding other providers.
2. In ordinary non-XYZzy production state with a writable save and original
   world records, select a distinct reachable destination and legal tonne
   commodity with actual stock. Normal Mission Contacts/Gallery discovers T04
   without manual pack installation, fixture endpoint injection or trial-profile
   reset. Preview/Back changes no commander or market state.
3. When destination equals origin, show a truthful actionable route-selection
   hint and refuse confirmation. Preserve missing-world/content, unavailable
   stock/capacity/fitting/fuel and unlimited-funds/fuel refusals. Do not turn an
   unavailable state into a fabricated valid route.
4. Through normal native controls/contacts, confirm the route/fitting, buy the
   identified tonne, perform actual travel, sell at its selected destination and
   return to the issuer for reception. Retained buy/sale/fuel/arrival receipts
   drive the outcome; an actual loss-making sale is valid. No tutorial cash
   payment. Clue appears once only at real reception.
5. Actual writer failure on an affected entry/confirmation leaves full
   commander, market, receipts and clue unchanged. Ordinary current-format cold
   load can resolve the bundled exact pack and resume the same accepted plan.
   Preserve relevant existing native accounting/rollback results; do not rerun
   unrelated scenarios or broaden save tests.
6. Native pack validation and focused owned tests must PASS; one independent
   bugs/performance/style review must be CLEAN before G1 integration. Keep unit
   responsibility with the author, batching wider checks at existing
   checkpoints.

## Limits and handoff

This recommendation needs Root's 9-path dispatch approval, not another physical
producer, save format or numerical design decision. Preserve existing
original-world source, reward0, real costs, one-tonne reservation and
normal-only qualification. Do not change approved pack bytes/digest to hide an
unrelated failure. If the normal production binding test exposes an actual
missing provider beyond this scope, report the exact failure/path to Root rather
than inventing a test binding or calling distribution complete.

No implementation, test/build job, new artwork, broad audit, source activation,
full M05/tutorial milestone completion or playable/release qualification is
claimed. G1 owns the current ledger and actual integration record. Designer
remains on standby after supplying this one handoff.
