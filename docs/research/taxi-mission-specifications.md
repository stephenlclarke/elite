# Taxi Galactica 2.2 ship contracts

O07 P39 is a ship-passenger generator plus one Ambassador assignment. It remains in the active ship-based scope; boarding means a docked service/berth transaction, without ground/on-foot play. The hashed package/main/condition/equipment files are in [provenance](data/oolite-pack-sources.json), numerical NPC records in [expansion resources](data/oolite-expansion-resources.json), and 28 original-callback checks in [source fixtures](data/taxi-source-fixtures.json). O08 supplies the native passenger payout/expiry readers. This establishes the core generator and source quirks; runtime source-version compatibility still needs game fixtures.

## Station, equipment and offer generation

Populate one Taxi Station in a corporate system (government7), outside interstellar space and with a non-nova sun. Position is psu [0,0,0.1], oriented toward the main planet, with a billboard10,000 forward. An interface appears only at a taxi_station role. There is no galaxy, combat-score or reputation gate in the inspected generator. One taxi job is active at a time; other independently owned passengers still occupy capacity.

The taxi passenger berth costs8,250 decicredits (825 credits), occupies5 cargo tonnes and supports repeated purchase. Its condition permits purchase only at a taxi station; scripted awards are allowed anywhere. Buying the dummy berth removes it and awards the standard EQ_PASSENGER_BERTH. A no-room bulletin board does not offer acceptance.

The welcome visit generates three offers. Each has a two-part random name, a destination selected within a nominal40-LY bound, a uniformly generated integer10..20-day deadline allowance and difficulty0..2. Destination selection initially uses systemsInRange, shuffles with random comparator and tests the candidate-to-origin route distance. That random sort is not a stable uniform shuffle across engines. The selector's index begins at-1 and an empty candidate array raises TypeError; if no candidate has an eligible route, it can return the last unsuitable candidate. A project repair filters actual nonzero reachable route distances first, then samples a saved seeded list. If none qualify, display no available job.

Let d=round(direct system distance in LY). The fare is random_integer*d/2: Easy 100..300, Medium 300..500, Hard 500..800. The displayed distance is rounded to.2 LY instead. Do not use the displayed distance or routed distance in the fare formula. Odd products can produce half-credit offers; the native payout later reads an integer fee. Reopening the initial welcome can generate new offers; once accepted, freeze that instance's chosen fields.

## Acceptance, deadlines and native payment

Acceptance copies the selected passenger/name/system/difficulty/fare/day count, sets ON_THE_JOB and calls addPassenger(name,start,destination,clock.seconds+days*86400,pay). No advance or risk argument is supplied, so O08 defaults both to 0. The script ignores addPassenger's Boolean result. The native API rejects missing berths or an already tracked passenger name; repair acceptance to commit only after the actual unique passenger is aboard.

O08 processes passenger contracts only at the main station. Let eta=int(arrival_time-ship_clock), truncating toward zero. At the destination, eta>0 is on time; eta<=0 is late. Thus a fractional second before deadline can already enter the late branch. At a wrong-system main station, expiry occurs only when eta<0. A non-main-station docking does not process the payout/expiry reader.

For an on-time passenger, read the fee as an integer. While a random draw<0.75 and eta>3,600, multiply the fee by 110 then integer-divide100, and halve eta using integer truncation. The condition consumes the random draw before testing the time bound. Each successful iteration gives a further compounded tip. Pay the resulting fee once, remove the passenger and increase native passenger reputation by RepForRisk(0)=1.

For a late arrival, integer-divide the fee by 2, then keep integer-halving while random<0.5. Pay that result and remove the passenger; this branch does not invoke the reputation increase/decrease functions. At another main station after expiry, pay nothing, remove the passenger and decrease reputation by 1. Native credits internally use tenths; the payment reader adds10*integer_fee. A fractional offered fare is therefore not automatically retained at hand-in.

Native reputation keeps good/bad/unknown counters capped at 70. An increase shifts one bad to unknown if bad>0; otherwise it reduces unknown if possible and increases good. A decrease shifts good to bad when available, otherwise unknown to bad. Keep this source rule separate from any simplified project reputation adapter.

## Encounters and completion quirks

Each population draws an integer1..100. The table shows additional authored taxi adversaries, alongside whatever the normal universe creates. Destination means matching the stored system ID; the source does not also check stored galaxy.

| Difficulty | Spawn predicate | En route | At destination |
| --- | --- | --- | --- |
| Easy 0 | roll>80 | 1 pirate | 3 pirates |
| Medium 1 | roll>60 | 2 pirates | 4 pirates |
| Hard 2 | roll>40 | 3 pirates | 5 pirates |
| Ambassador3 | En route roll>30; destination unconditional | 4 separatists | 8 separatists |

Spawn on route wp with the engine's default position argument. Source pirate variants are Mamba, Cobra III, Asp, Python, Krait and Cobra I; separatists are military-laser Krait/Mamba variants. The full resource definitions retain speed, energy/recharge, missiles, ECM, AI and role weights. The six taxi Adder liveries are role/paint variants, not six new canonical hulls.

The script's own completion is a main-station mission-screen check for ON_THE_JOB and matching destination system. It does not inspect the native passenger, deadline or payment outcome. It marks NOT_ON_JOB, increments taxijobstotal and refills fuel to 7.0; a special job also marks its story complete and sends optional news. This can count a ghost job after a passenger has already expired elsewhere. It also leaves taxi_diff unchanged, so taxi pirates can continue to spawn after completion. These defects are directly checked in the saved fixtures.

An unset missionVariables counter is null under O08, not ordinary JavaScript undefined. Consequently null+1 initializes taxijobstotal to 1. The getter/number conversion were traced in OOJSMissionVariables and OOJavaScriptEngine; do not report a NaN-counter defect based on an inaccurate mock.

Changing galaxy sets a transient _newGalaxy flag; the next dock removes the passenger, clears the job and sets difficulty-1. Startup resets that flag. Saving/reloading after changing galaxy but before docking can therefore retain a stale job. The project must persist accepted galaxy/termination, not rely on the transient flag.

## Ambassador and project repairs

After at least five counted taxi completions, with a free berth and no completed Ambassador flag, a taxi-station welcome offers the special assignment. It generates a destination with nominal20-LY route bound,10..20 days and fixed10,000-credit base fare. Acceptance sets difficulty3; the native engine still applies its on-time/late fare rules. Destination arrival sets MISSION_COMPLETE and optional news. There is one story assignment, not a new canonical mission for every random ambassador/destination.

The repaired ship-only project profile must filter valid destinations, persist generated offers/accepted galaxy, accept only on successful passenger installation, clear failed jobs, require an actual delivered passenger before incrementing completed count, and clear difficulty after termination. Preserve valid late native delivery as a completed trip if using the source payout profile; do not silently replace it with a new hard failure. Store all berth/passenger identities during hull changes and block a switch that cannot carry them. No passenger goes into surplus-equipment storage.

Check the three RNG endpoint/midpoint generation cases; every strict encounter threshold at equality/+1; one/zero berths; duplicate passenger name; addPassenger failure; fractional fare/native rounding; eta just before/equal/after zero; exact3,600-second tip boundary; wrong/non-main station; ghost completion; five-trip special gate; special decline/reoffer; same numeric system in another galaxy; and save/reload before post-galaxy docking. The28 current callbacks cover selected generator/encounter/acceptance/completion defects, not a running Oolite playthrough or compiled native-payment parity.
