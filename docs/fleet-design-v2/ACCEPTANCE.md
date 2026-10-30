# Acceptance and implementation checks

The design validator checks source records only. It does not run the game, generate portraits, repair meshes, prove collision clearance or establish balanced gameplay. `VALIDATION.json` reports its exact scope. The tests below are requirements for the relevant implementation owner, not work started by this authoring session.

Its kit arithmetic uses proposal planning weights. Native quote/runtime acceptance must first resolve [EQUIPMENT-MAPPING.md](EQUIPMENT-MAPPING.md), including current intrinsic/laser/EMP/FuelStorage differences, typed sockets, explicit new-device mass/power and cabin aliases. Do not label a worksheet PASS as actual paid fit or native slot support.

## Design completeness

- Exactly SH001-SH171, unique stable IDs/display names, all original input stat/geometry fingerprints retained.
- Full performance for each flyable/work hull, or an explicit environment-only definition; no SH163 placeholder.
- No identical functional performance profiles masked by a different price. No arbitrary ID-derived random jitter.
- Trader and transporter base cargo meet 25t/150t floors. A standard proposed role fit must also leave those floors where the ship is sold as a trader/hauler; passenger/rescue conversions must instead state the actual remaining cargo clearly.
- Each real recommended role kit fits its utility/equipment budget, leaves the four-unit core foundation and consumes its actual hold/money. Cabin packages fit both hold and equipment limits.
- Capital/escape/station/probe access is explicit; Medusa's unique gate remains; Kestrel has no external missile pylons; protected names survive.
- Tithe has three explicit variants, exactly four/two/two original reserve identities and no automated resource or reinforcement reset.

## Per-family code and actor checks

Use meaningful boundary cases for actual code changes: loader rejects malformed/negative/nonfinite fields and invalid ID/material/unit joins without partial admission; quote/commit use identical prices and fit; a failed ship exchange changes no cash, inventory, people, mission custody or source receipts. Store unsupported portable equipment as retained owned overflow, never silently discard it.

Verify the real selected weapon, supported facing and fitted utility using W/Return/E/Q. Missing equipment cannot produce mining, cutter, rescue or survey progress. Real finite ordnance and correct energy/heat apply. Survey receipts still require actual geometry, consent, fit and dwell; rescue still needs real compatible people/places and receiving. A support designation grants no invisible ally effects.

The unmanned quest Medusa requires the narrow typed original-construct EMP/custody adapter described in EQUIPMENT-MAPPING.md. Check genuine source/stage/actor/world permission at charge, release, disable and salvage, with negative protected/wrong/replayed/occupied cases. Do not satisfy a human-crew guard by adding fictitious crew or by globally admitting mission actors.

Crew places remain separate from purchased passenger places and assigned people. An occupied cabin cannot be sold/refitted as empty. Minimum crew cannot be faked by a numeric projection. Unsupported crew-service requirements block honest activation until the named prerequisite exists.

## Physical and visual checks

For every admitted family, show the actual detailed and native meshes in front/rear/top/side and an actual full rotation. Preserve common physical scale for comparison. Check cockpit support, structural joints, material/UV consistency, scale and openings. Buffalo/Wildebeest/Tapir must visibly have attached cockpits; no other family is exempt.

Use meaningful physical bound/clearance checks against the actual compatible doorways and target-relative motion. Oversized haulers use a compatible berth or an honest refusal; never shrink the hull to fit every station. Native geometry preserves useful gaps rather than enclosing them in a solid box. Record per-hull native query budgets; do not solve performance by silently increasing global solver limits.

At near/medium/distant ranges, human panels must read as recessed continuous service detail without repeated spots or shimmer. Larvaal remain intentionally smooth. Drone has exactly three stable openings and the gold core. Medusa keeps the selected continuous ellipse, pod angles, organs and projections. Family variants have visible functional differences, not just a colour swap.

## Tithe and discovery checks

Ordinary Mule/Gyrfalcon/Bison remain human models. An ordinary AI-piloted NPC is not automatically a Tithe conversion. The correct faction plus TN ID selects the blocky mesh and uncrewed actor policy. Destruction does not manufacture crew escape pods, kills, cargo or replacement reserves. Reload preserves the remaining original eight identities and actual resource orders.

Unknown base/variant stays silhouette; encounter records location and reveals wireframe; actual commander-attributed EMP disable and authorised physical section intake grant the correct blueprint. Tithe variant discovery does not falsely count an ordinary parent acquisition or add a second base-hull completion credit. Paid safe conversion consumes actual money/fitting/hold and removes the rogue controller. Station docking and Medusa's ordered clue/trail/EMP-disable/lattice-intake/PLUGH-receiving gates remain tested separately. Follow all [salvage/EMP source acceptance cases](SALVAGE-ALIGNMENT.md), including finite banks, the no-fee Medusa service loan, protected sovereign core, physical 50kg lattice, actual loss/retry and optional paid hull purchase. A destroy-only producer or a temporary disable must fail acquisition.

## Presentation and release

Show hull classification, actual use, crew requirement, hold after fit, passenger places, range/tank distinction, supported weapons, equipment costs and missing role requirements. Compare the same real carried fit where transferable; green/orange/cyan and better/worse/same text must agree with quote/runtime values. Do not mark price, crew requirement, charge time or fuel consumption as better merely because the number is larger.

README/help, mission dialogues, catalogue, generated central Markdown and GIFs use the same current names and controls. Actual renderer media is invalidated by effective ship inputs. Formal release gates follow the current repository/human workflow; this proposal does not claim to have passed them.
