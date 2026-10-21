# Project estimates and source fidelity

The [active scope](implementation-scope.md) takes precedence: no Frontier/First Encounters, Operations or ground/on-foot mission may be enabled through estimates.

On 13 October 2026 the owner explicitly authorized: "Use labelled estimates only where necessary" for mission parameters that surviving sources cannot establish. Missing player capabilities were already authorized for estimation. An estimate can make a documented mission playable in the new game; it cannot establish what the original executable or live server did.

Use a value from the selected source profile first. Where sources disagree, retain both profiles and select one explicitly. Where a numerical parameter is unavailable, supply a deterministic project value with status estimated, source gap, rationale, units, supported difficulty and acceptance boundary. Do not replace a known inconvenient zero reward, cargo limit or strict comparison with an estimate. A corrected source defect is a repair, with original and project outcomes documented separately.

A mission still needs an established objective/branch sequence. Authorization to estimate a timer is not evidence that an unexamined expansion contains a particular campaign, or that an unfinished historical branch was playable. Unknown inventory, routes and causal branches remain research gaps. Keep discovery records outside the count of fully specified missions.

## Required estimate record

Every estimate must identify canonical mission/ship ID, version profile, field, value, units, evidence status, source references, reason an estimate is necessary, method/reference, confidence and validation boundary. Persist the chosen project profile ID and revision in saves. A later corrected estimate requires a save migration for active objectives or equipment; do not silently change an active deadline, target count or hull capacity.

For missions, the completed project profile must specify offer eligibility, acceptance/refusal, destinations/coordinates, objective identities/counts, enemy hull/loadout/AI, wave schedule, timers and interruption rules, success/failure, rewards/penalties, abandonment/retry, ordering, saved fields and success/failure/reload checks. Label each filled numerical gap individually. A generic default attached to an entire expansion is insufficient.

For ships, source values, borrowed edition values, conversions and estimates remain individually visible in [player profiles](data/player-ship-adaptation.json). Unknown geometry uses an explicitly named provisional surrogate; a mass/cargo ratio is not a measured volume. All 161 current whole-craft catalogue entries have numeric common-flight profiles. That does not establish exact geometry, original player capabilities or every discovered expansion hull.

## Implementation boundary

The common project flight profile uses O08-style arbitrary speed/energy units and seconds, with a Cobra Mk III speed reference of 350. Earlier GBA examples use300 and remain separate; the complete common profiles explicitly multiply those speeds by 350/300. D23 ED speeds, armour and base shield inputs are translated relative to its Cobra 280/120/80, with 350/256/128 project references. This is a labelled gameplay conversion, not ED simulation parity. Native ED outfitting slots, module data and loadouts remain separately available.

Generic optional equipment has an explicitly estimated project capacity budget of 8+floor(cargo/5) units, minimum8. The dataset supplies costs and compatibility handling. Intrinsic docking computer/drive are already reserved and consume no second cargo deduction. Passenger berths consume5 tonnes and1equipmentunit each. A fitted cargo expansion costs1equipmentunit and adds only its selected hull extension; these common fit costs are labelled estimates. Unknown equipment is preserved in storage until its compatibility adapter is defined. Mission items and passengers never silently become surplus equipment.

The final implementation handoff must distinguish filled project profiles from unresolved historical fidelity and remaining unexamined campaigns. It must not describe a package archive, raw script index or source dictionary as a fully checked playable mission.

The first-berth default is0; [SH169 Sunray](commies-selected-ship-specifications.md) explicitly has one source-standard fitted owned berth, reserving5tonnes/1equipmentunit on genuine first acquisition. This specific exception is sourced, not a general free-cabin estimate. Authoritative native ship TOML game/calibration/economics remain separate from research JSON: preserve existing maintained values when refreshing sources, apply documented calibration to newly implemented hulls, and never claim ignored source fields implement cabin/storage or multiple-emitter capabilities. Historical source shipyard prices are evidence; actual native purchase/exchange quote rules govern the game.
