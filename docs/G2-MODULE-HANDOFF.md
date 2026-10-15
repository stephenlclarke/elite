# Encounter and mining modules

These independent modules require G1 runtime integration. Passing module tests
does not establish delivery in normal play.

`EncounterDirector` consumes canonical `EncounterContext`, schedules absolute
physical-time decisions and returns admission batches and NPC intents. G1 admits
whole atomic pirate packs and supplies receipts. Pending requests reserve
capacity. Mission actors and payloads remain protected from ordinary AI.

`TrafficIntent` follows real station/arrival routes, targets available ordinary
cargo and flees recorded attackers or superior police. Miners approach generated
fields and live rocks, recover released ore and skip depleted fields. G1 fills
`depletedRocks` with current-system terminal identities, activates fields around
miners as well as the player and resolves physical steering, shots and scooping.

`MiningFields.generate(anchors:seed:)` returns deterministic canonical positions,
stable rock identities, radii and energy. Its bounded placement checks complete
rock envelopes against planet, sun and station margins. Short bands use a safe
deterministic shell. Show field beacons before physical asteroid admission.

`MiningLedger.hit(rock:incident:damage:)` requires the actual physical rock and
globally ordered incident IDs. Only a Mining Laser final depletion produces ore;
other weapons destroy without ore. All supported laser mounts work. The ledger
commits depletion before requesting any pod admission. On `capacityRefused`, G1
must retain the rock at `remainingEnergy(for:)` rather than deleting it.

Ore is Minerals in one-tonne pods, sometimes Alloys, and rarely one native
kilogram of Gold or Platinum. `pendingPayloads` carries actual commodity amounts.
`collect` is an atomic complete-pod transaction requiring fitted scoops, a valid
physical approach, capacity and mission protection. Kilogram and gram commodities
consume zero commodity tonnes. Refused pods remain collectible. NPC and player
collection must share this same ledger.

Use `pendingSpawnRequests`, followed by `acknowledge(receipts:)`. Call
`cull(actor:)` for physical removal and `resetPhysicalBindings(system:)` when
rebuilding a saved scene. Call `depart(system:)` only on actual departure: this
explicitly expires abandoned ore while preserving damage and permanent depletion.
Pending and partial records are capped at 256; exhaustion refuses work before
mutation. Depletion uses compact masks, including the special Plugh system.

`TypedCargoPayload.wreck` preserves an actual available ordinary manifest,
excluding protected actors and payloads. G1 owns exactly-once destruction/drop
settlement; this constructor alone is not a wreck persistence ledger.

Manual mining remains available without targeting automation. Player automatic
rock hold/tool selection requires the independently installed Mining module;
wreck/debris automation requires the Salvage module. Core targeting tiers do not
grant these extensions. G1 owns shop, save, controller, status, help and actual
equipment gates; NPC intent does not depend on the player's purchased modules.

Validation: 22 focused release tests pass across encounters, traffic, field
safety, irreversible extraction, native cargo units, admission retries, protection
and save/cull/revisit behavior. Final integrated normal-play scenarios and full
CI remain G1 release gates. Salvage extensions are a separate pending slice.
