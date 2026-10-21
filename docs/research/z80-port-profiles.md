# MSX and Spectrum mission source profiles

Updated 13 October 2026. These profiles narrow the MSX-DISC and ZX128 gaps using identified disassemblies and, for Spectrum, directly inspected tape bytes. They do not establish mission parity for MSX cassette, original Spectrum 48K tape sides, CPC or Einstein. Galaxy indices are zero-based. Canonical mission IDs remain C01/C02/C04/C05/C06; these are additional profiles, not duplicate missions.

## Evidence and boundaries

S41 is Ricardo Bittencourt's [Firebird/Mr.Micro MSX disassembly](https://github.com/ricbit/elite/tree/6bfa450047c54979b0588f317eda63c8ddabede1), pinned to commit `6bfa450047c54979b0588f317eda63c8ddabede1`. The README identifies a single-sided 360 KB disk, with files loaded from absolute sectors. Inspected `code.asm` and `shapes.asm` establish scheduler instructions, objective transitions and resource fields. A retail disk comparison or complete original-game run has not been performed. The source's comments occasionally misname object types: instructions comparing 0x1E/0x1F refer to Cougar/Constrictor, even where a comment calls them Thargoid/Thargon. The notes below follow instructions and the blueprint table.

S42 is the [Spectrum 128K compatibility release reconstruction](https://github.com/ataribaby42/zx-elite/tree/2a06565273bd3898f7f03d81776aedb80bbfd26d), commit `2a06565273bd3898f7f03d81776aedb80bbfd26d`. This is a 48K memory-model game sold as a 128K-compatible release. The default reconstruction uses Krait and original laser settings; optional bug fixes, Adder and other build options are separate adaptations. The upstream project reports a byte-identical build, but that assembly check has not been independently repeated here. We downloaded the reference TAP, SHA-256 `d9013872555f448308e0b8a69b624600335384cd38911165bde74a9d11de84d6`, parsed all blocks and verified their XOR checksums, extracted its complete 19-entry blueprint table, and independently matched eight mission instruction sequences to the tape image. This verifies those bytes, not mission playthrough outcomes.

All inspected files and three Spectrum tape references are hashed in the [primary-source manifest](data/primary-source-files.json). [MSX object resources](data/msx-object-resources.json) contains all 31 nonzero object-table entries, including four title letters. [Spectrum object resources](data/spectrum-object-resources.json) contains all 19 headers from each of the compatibility, fixed 48K Krait and fixed 48K Adder tapes, plus the eight instruction comparisons. Geometry is not bundled. The fixed 48K tapes establish their own blueprint data; they do not prove their mission routines match the compatibility release.

## MSX-DISC scheduler and saved fields

`ARRIVE_CHART_REF_NORMAL` at 0x8A4D counts an arrival only if galaxy !=0 and `VIEW_MODE ==0`. Decrement the byte at 0xE93B; on zero reset it to 64 and call `ADVANCE_BRIEFING_STEP`. That routine at 0x908C returns if step==6; otherwise increment the step at 0xE93C and set mode to `(step-1)*16`. The embedded new commander starts step=1, mode=0, countdown=64, giving modes 0x10, 0x20, 0x30, 0x40 and 0x50 in that order. No combat-score test appears in this scheduler. Witchspace arrival takes a separate branch and does not decrement the normal countdown. Galactic-jump arrival subsequently reaches the same normal-arrival routine when it is not a misjump; test it as a counted arrival when the new galaxy is nonzero.

The 128-byte commander payload stores briefing step at +0x75, mode +0x76, displayed destination +0x77 and countdown +0x78. It also stores cargo, equipment, the clue countdown and combat score through `COMMANDER_FIELD_MAP` at 0xA581 onward. These fields must survive save/reload; merely saving a boolean mission-complete array loses active stages. The RNG and in-flight object state are not fields of this commander map.

The three-byte `GET_RANDOM` routine is at 0x2176. For previous bytes x,y,z at 0xE936..0xE938: move y to z and x to y; let t be `((oldZ<<1) | (oldY<128 ? 1:0)) &255`; new x is `((oldX>>1) | ((oldY&1)<<7)) XOR t`, and return new x. This follows carry propagation through RL/RRA. Some other routines use the CPU refresh register R, including cargo-quantity selection; a three-byte RNG seed alone does not reproduce every simulation event. Preserve call order and platform frame timing rather than converting every routine to independent random draws.

## MSX-DISC C01 Constrictor

Mode 0x10 dispatches `SHOW_NEAREST_SYSTEM` at 0x9120. Reset frame state and `EQUIP_SCAN_GATE`, then find the nearest system to the current `CHART_SEARCH_COORD` pair and store its index in `DISPLAYED_SYSTEM`. This is a procedural selector, not a fixed BBC target. Answer N clears mode and consumes this scheduled assignment; any other returned answer increments mode to 0x11.

While docked in the displayed system, the system-data screen advances 0x11->0x12 and supplies the first clue. A galactic jump in mode 0x12 advances to 0x13, sets the displayed system to the new jump target and initializes clue count to five. In 0x13, viewing data while docked at the current displayed system advances to 0x14 and selects another non-current system from the generated short-range chart list (`PICK_RANDOM_SYSTEM`, 0x50AA). Decrement the clue count; on zero advance again to 0x15. An ordinary jump changes 0x14 back to 0x13. In 0x15, docking in the displayed system advances to 0x16; the system-data display supplies the taunt, and launching changes 0x16->0x17.

At the next hostile-spawn check, mode 0x17 forces a Constrictor, type 31, then increments mode to 0x18. Its destruction through `APPLY_SHIP_DAMAGE` increments mode again; mode 0x19 debrief pays 100,000 cash tenths, exactly 10,000 credits, and clears mode. Returning before destruction changes 0x18 back to 0x17, permitting another forced target. Check event order and allocation failure: the force routine increments mode after the call, without a success test.

Constrictor blueprint: energy255, collision radius75, hit radius36, behaviour 0x3E, missile flags 0xFF, loot 0x72, aggression150, bounty4,000 tenths (400 credits), raw combat-score award5,000. The bounty is separate from the 10,000-credit debrief. Laser damage to types30/31 is right-shifted twice, irrespective of a BBC military-laser rule. Destruction requires subtraction underflow; reducing health exactly to zero follows the survived path. Collision with Constrictor applies player damage255. Resolve score display scaling and all missile/AI readers before treating the raw score word or missile flags as familiar BBC values.

## MSX-DISC C02 naval documents

Mode 0x20 uses the same nearest-to-chart-reference selector and accept/refuse routine. Accept ->0x21 and sets `SAVED_VIEW_MODE=1`; N ->mode0. Docking in the displayed destination while mode 0x21 grants energy-unit flag2, clears both mode and saved-view flag, and does not add cash. Thargoid type19 is selected for hostile encounters while mode 0x21. The in-system travel encounter test uses threshold zero in that mode, calling the hostile spawn when its random byte is greater than zero. Do not reuse BBC Galaxy 3 destinations, 1,280-kill eligibility or a 256-point debrief bonus without separate MSX evidence.

## MSX-DISC C04 nova rescue

On the scheduled arrival, mode 0x30 drains the remaining fuel one unit per two HALTs, then waits three HALTs per iteration using B=`70 - fuelBeforeLeak` restored from the pushed A register. B=0 means a 256-iteration DJNZ loop. This is instruction/frame timing, not a two-hour countdown. Mode then becomes 0x31. Refuelling is blocked for every mode whose high nibble is 0x30.

The mode 0x31 station screen increments to 0x32 and clears all 72 cargo bytes **before** asking for consent. Therefore refusal also destroys prior cargo. Y calculates free space after that clearing, copies its four-byte quantity to the refugees cargo field at 0xEB5D, and advances to 0x33. Any other response remains 0x32. During modes 0x32/0x33, sun-distance calculation adds `SUN_APPROACH_OFFSET`, then subtracts100 from the offset per evaluation. Launch resets that offset to zero in the 0x30 family. Do not model this solely as a fixed nova countdown.

At the next executed hyperspace transition,0x33->0x34; every other 0x30-family mode becomes0. The 0x34 debrief clears the refugee quantity and **replaces**, rather than adds to, the four-byte gem quantity with50. The source identifies gem units as grams: the earlier report of50 kg is incorrect for this profile. Mode then clears. No cash award or combat-score increase appears in this debrief. Escape feasibility, galactic-drive requirements, sun arithmetic overflow and the exact docking/jump event sequence still require a selected-disk fixture; do not claim those closed from this partial routine trace.

## MSX-DISC C05 cloak

Mode 0x40 forces a Cougar (type30) at a hostile-spawn check, then increments mode. Its group can contain Asp Mk II (type25) escorts; the escort count is a rejection-sampled byte from `R&31`, accepted below `(KILL_COUNT+3)` followed by RRA with its preceding ADD carry. Retain the eight-bit arithmetic, including a possible zero limit, rather than inventing a fixed escort count.

Cougar energy255, collision radius67, hit radius36, behaviour 0x26, missile flags 0x87, loot 0xFF, aggression150, bounty5,000 tenths (500 credits), raw score1,000. Laser damage is quartered as for Constrictor. Cougar is excluded from the ordinary collision check. Its despawn resets mission mode to0; that does not prove the player acquired the cloak.

Loot 0xFF takes the one-piece path. The canister's cargo becomes 0xFF after the special loot-type arithmetic. Negative cargo bypasses ordinary cargo-capacity checks when scooping: require scoops fitted, Z high byte nonnegative and Y high byte negative, then set `CLOAK_FITTED=1`, show the equipment message and remove the object. A full hold therefore does not block this acquisition predicate. Such a canister is laser-immune in the inspected damage routine. Available object slots, destruction method and the ordinary movement/collision helpers remain encounter dependencies. Y toggles the awarded cloak; the activation field is transient and is not the persistent fitted flag.

## MSX-DISC C06 captured station

Mode 0x50 displays intelligence and increments to 0x51. The next hyperspace execution changes 0x51->0x52. In 0x52, docking and escape-pod keys refuse, station laser damage is one quarter of the applied laser power, ordinary station laser damage is zero, and the station's response spawns Thargoids instead of Vipers. Hostile encounters also select Thargoids. Destroying the station through the damage routine decrements `STATION_DRAW_GATE` and increments mode to 0x53. That mode's debrief grants `MISSION1_REWARDED=1` and clears mode; despite the misleading variable name, this is the ECM-jammer award used by the L-key handler. No cash amount is added there.

The 0x52 value is a mission mode, not sufficient evidence that `WITCHSPACE_FLAG` is set. Normal hyperspace also separately rolls12/256 for an actual misjump. Preserve that distinction. Station/debrief placement, collision alternatives, abandonment and scene restoration need runtime fixtures before this profile can be called fully replicable.

## Spectrum compatibility release scheduler

At 0xD7C0, galaxy0 skips mission scheduling and the pirate-boarding eligibility path. Otherwise a separate transient flag can divert before the jump increment; after that guard increment the 16-bit word at 0xA825. Read mission flags at 0xA872 and select the **first unset trigger bit**, checking only the incremented low byte L:

| Unset bit | Low-byte comparison | Activation |
| --- | --- | --- |
| 0 | >=0x20 (32) | Set bit0; set 0xA843=1, dispatch event2 and invoke the fuel routine with A=0. |
| 1, after bit0 is set | >=0x80 (128) | Set bit1; the cloak-encounter generator can now run. |
| 2, after bits0/1 are set | >=0xFE (254) | Set bit2 and mission state 0xA871=1. |

This is not a full 16-bit comparison. If the low byte wraps before an unset mission trigger is handled, the next opportunity follows that byte's threshold again. These are activation flags, not verified completion flags. The scheduler itself does not require nova success, cloak acquisition or a competence rating before setting the later trigger bits. The included old forum notes' stronger completion-prerequisite claim is not established by these instructions. Read the whole flight path before counting every possible jump as reaching this guard.

The persistent region begins at 0xA816: jump word at offset 0x0F, mission state at 0x5B and flags at 0x5C. The compatibility tape transfer is 104 bytes; the restart snapshot preserves the first 102. Death/restart restores the last successful save/load snapshot, rather than the continually changing active record. This differs from an autosaving remake.

## Spectrum compatibility release outcomes and encounter facts

- Nova consent routine 0xB27B sets flag bit5, marks the large-cargo flag and clears 17 cargo commodity bytes on Y. The later delivery routine 0xB474 requires the activation byte 0xA843 to be zero and bit5 set; it clears bit5, increments the high combat-score byte 0xA824, **sets** gem quantity 0xA83C to100 and sets free-hold field 0xA83E to35. This is replacement arithmetic, not an additive100-g reward. The required activation-byte clearing path and escape/debrief event order remain to be fully traced.
- Cloak acquisition routine 0xA8AA sets flag bit6 and increments 0xA824. It is called by the 0xFF special cargo path. When `(flags &0x42)==0x02`, the cloak encounter path at 0xF639 admits a random result below255, marks a per-system spawn latch and attempts an Asp (ID13) followed by a special event for Krait escorts. Exact object-slot failure and escort event semantics remain unresolved; do not substitute MSX Cougar statistics.
- The 0xD243 completion routine increments 0xA824, clears mission state and sets flag bit3, associated with the ECM-jammer award. Incrementing 0xA824 adds 256 whole kill points with byte wrapping; it is not a cash award. The three observed award routines therefore corroborate the historical report of 256 points per mission for this identified profile, subject to reaching each routine through the original event graph.
- Asp base header: speed40, energy150, bounty 20 credits. Thargoid: speed39, energy240, bounty50. Krait: speed30, energy80, bounty10. Coriolis: energy240. Mission instance flags and damage rules must still be applied; blueprint values alone do not prove a complete encounter.
- Station combat in mission state4 has a distinct Thargoid launch path: encounter count<4, hostile station, first random byte<0x24, then another<0x88. The source also contains calm-station trader traffic and special mission collision/state changes. These need to be joined to the briefing graph before specifying the final mission's complete failure/success behaviour.

Spectrum remains R2 for complete mission fidelity. The scheduler, selected rewards, saved offsets and hull headers are now established for the pinned compatibility tape. Still required: trace every state 0xA871 write, briefing accept/refuse paths, nova timer/escape rules, special cargo eligibility, cloak flicker/escort/damage handlers, captured-station route and final debrief, then run successful/failed and save/reload fixtures. Original protected48K sideA/sideB mission code remains a separate profile.

## Required parity fixtures for these sources

Test MSX countdown1/0/255, step5/6, galaxy0 versus nonzero, ordinary/galactic/misjump arrivals, refusal after a consumed slot, all five clue selections and a loaded in-progress save. Test Constrictor health reaching exactly0 versus underflow, failed allocation, cash carry, and bounty versus debrief rewards. Test nova refusal with an occupied hold, accepted gem replacement, full/empty fuel delay and rescue after normal versus galactic jumps. Test cloak loot with a full hold, without scoops and with exhausted object slots. Test station docking/escape refusal, destruction and restored ordinary population.

For Spectrum test low jump bytes31/32,127/128,253/254,255/0 with different trigger-bit combinations and high bytes; verify no kill-rating dependency at the scheduler. Test high-score-byte255 wrapping on all three awards, gem replacement and mission-state restoration after death/save/load. Record the identified tape/disk, start save and final balances/entities; source inspection and TAP checks are not substitutes for these original-game outcomes.
