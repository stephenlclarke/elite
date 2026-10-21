# Xeptatl's Sword 3.0 source profile

O07 P48 is Spara's 3.0 update recovered from the [wiki download record](https://wiki.alioth.net/index.php/File:XeptatlsSword.oxz) on 13 October2026. The archive is22,000,169 bytes; its package/file hashes are in [provenance](data/oolite-pack-sources.json). The wiki upload is2 November2022. Treat this as a separate revision from Smivs's original2.3. Its61 resource definitions resolve against pinned O08, but the source also has concrete defects requiring a project repair profile.

The [50 source fixtures](data/xeptatl-source-fixtures.json) check36 dock-stage transitions, eight choices/payments, two pylon gates, three finale timer states and successful Lave group/leader construction. They execute callbacks with an O08-based script-object scope approximation and mocked Oolite APIs, not a released game. Exact target/turret/AI fields are in [expansion resources](data/oolite-expansion-resources.json). The rule index records additional source control syntax; it is not an evaluated campaign graph.

## Offer and first circuit

On a witchspace exit in galaxy 5 (zero-based4), an unset campaign becomes OFFER only when the native cloaking mission variable cloak is COMPLETE. That initial exit sets jumpCount0. Subsequent exits in that galaxy increase the count; at >=3, a main-station or xs-station docking can offer the campaign. Refusal sets NOT_NOW and resets the count, allowing another offer after three more qualifying exits. Acceptance sets STAGE_0 and marks Inbe, system 129. The public requirement of two pylons and scooping becomes important later; a general hyperspace drive does not replace a galactic drive.

The following coordinates use zero-based galaxy numbers. Station-role predicates matter; docking at the wrong station does not satisfy a special-base objective.

| Stage | Required event/location | Result |
| --- | --- | --- |
| 0 | Dock galaxy 4/system 129, Inbe | 1; route to Estebiin. Population adds two Thargoids near the witchpoint, radius 7,500. |
| 1 | Dock galaxy 5/system 55 at xsheadquarters | Show briefing and immediately credit25,000. Choice1_Cont credits 10,000; 1a_Cont credits 20,000 and sets2a. |
| 2a | Enter galaxy 1 | 2d and marker105. The stage 2d hand-in is in galaxy 2/system 133, Ditere. Preserve intermediate navigation hints separately from this actual hand-in. |
| 2d | Dock galaxy 2/system 133; choice2_Cont | 3; reset jump count. |
| 3 | Galaxy 3/system 141, courier population | Courier spawn changes3 to 3ab. Its death drops a computer within radius 50; player scoop changes to 3ac. |
| 3ab or3ac | Dock galaxy 4/system 9, Dioris | 3a; different briefing for missing/recovered computer, both continue. Clear special-cargo display. |
| 3a | Exit witchspace at galaxy 5/system 202, Qutius | Halve current energy, set forward shield0, remove working Galactic Hyperdrive and all GalDrive mine items; set3b. |
| 3b | Dock galaxy 5/system 202 | 4; mark Beanxeat41. |
| 4 | Dock galaxy 5/system 41 | 50. Remove station entities whose equivalent tech level >8 to prevent access to inappropriate equipment. |
| 50 | Beanxeat population/ship destruction | Anaconda wreck at sun-relative spm [0,0,-4*sun.radius], nine asteroids within5,000. Wreck death spawns two GalDrivePods and ten boulders within300. |
| 50 ->55 | Player scoops a GalDrivePod | Award Galactic Hyperdrive if not working; otherwise award GalDrive mine; set55. |
| 50 or55 | Dock galaxy 6/system 123, Inlabe; choice3_Cont | 60; mark Tiared194. The source permits continuing even without the wreck pickup. |
| 60 | Dock galaxy 6/system 194 | 70. |
| 70 | Begin jump toward89 from galaxy 6/system 194 | 71; replace interstellar populator for that route. A dumbell station appears within12,000 of the interstellar origin. |
| 71 | Dock interstellar dumbell station; choices4a/4b | 72; refill fuel to 7.0, mark Articeso229. Choice4c launches. |
| 72 | Dock galaxy 6/system 229 | 80; mark228. |
| 80 | Visit galaxy 6/system 228 | Two crystaloids plus Prolly helper at sps [0,0,3]. First crystaloid death spawns one special crystal, five splinters and five Thargoids25,000 ahead of player; set80a. |
| 80a ->90 | Player scoops special crystal | 90; special-cargo flag. Helper marks Ontiesed15. |
| 90 | Dock galaxy 6/system 15 | 100; clear crystal cargo display. |
| 100 | Main station galaxy 7/system 162, Oresrati | 110. This visit is optional: the switch deliberately falls through if already at the damaged monitor station. |
| 100 or110 | Damaged monitor station, galaxy 7/system 162 | 120. |
| 120 | Launch from damaged station | Spawn Black Mamba Boa if none exists, on route sp fraction.3. Its death drops a warhead, one long-fuse bomb and seven cargo pods. |
| 120 ->130 | Player scoops warhead | 130; mark special cargo. NPC scoop/destruction respawns the warhead. |
| 130 | Dock xsMonitorStation at galaxy 0/system 147, Diso; choice5_Cont | With two empty pylons, award warhead mine and booster, set140. Otherwise set135 and offer pylon clearing; when two free pylons exist, complete the same awards. |
| 140 | Main station galaxy 0/system 147 | 150; mark Lave7. |
| 150 | Begin jump toward7 from galaxy 0 | 160; replace Lave population. |
| 160 | Defeat Hive using assembled Sword | Hive death calls getRidOfThargoids and sets180; departure effects run in four-second steps. |
| 180 | Dock main station galaxy 0/system 7 | 200. Choice6a_Cont pays100,000 and marks Tionisla124. |
| 160 failure | Dock any galaxy 0 main station without completing Hive | 170. Choice6b_Cont explodes docked station; later launches spawn ten blitznests and 30 Thargoids. This is a failure continuation, not the successful second circuit. |

At stage 60, a zero/unset jump count is randomized to 0..2; otherwise increment it. On count >5, or in system 249/166, an ambush is queued and the count reset. The source adds tCount=2..4 Thargoids once, then adds tCount again on ordinary ambushes: total4,6 or8. In systems249/166, it adds five extra plus the helper instead: total7..9. Do not turn the first and second spawn calls into a single2..4 wave. On arrival a nearby Thargoid within25,000 targets the player.

Launching from the interstellar dumbell station adds the disc at station forward*-9,000 plus up*6,000, five alien ships and three IS Cobras within1,500 of the player. A five-second repeating timer sends four warnings, then stops at tick 5. The commented station explosion is not an active destruction rule.

The Black Mamba's dropped Q-bomb uses a30-second AI pause before energy-blast detonation. The warhead has respawn callbacks to remain recoverable. The player must assemble the original Sword using the warhead/booster equipment, recover the scoopable result and fire it at the Hive. The assembly object's death spawns the scoopable Sword within5; player scoop awards EQ_X_SWORD_MISSILE. Its AI intercepts to range25 with 30,000 travel cutoff, and detonation calls dealEnergyDamage(999999999,5,0.25). Preserve assembly identity, limited pylons and scooping capacity; source callbacks alone do not establish the complete collision/assembly outcome.

## Second circuit and Estebiin finale

These are main-station arrivals unless a timed encounter is stated. Each row advances the source stage and updates route markers/instructions. The [fixture table](data/xeptatl-source-fixtures.json) retains exact input locations and next states.

| From | Galaxy/system or event | To |
| --- | --- | --- |
| 200 | 0/124, Tionisla | 205 |
| 205 | 1/250, Vearin | 210 |
| 210 | 1/229, Lasoce | 215 |
| 215 | 2/63, Soiserla | 220 |
| 220 | 2/36, Birera | 225 |
| 225 | 3/236, Aaanqu | 230 |
| 230 | 3/178, Soralaat | 235 |
| 235 | 4/83, Geerin | 240 |
| 240 | Enter4/15; trader appears within3,000, message timer7 seconds | 245 |
| 245 | 4/217, Aroratla | 250 |
| 250 | Enter4/196; trader and 7-second timer | 255 |
| 255 | 4/229, Xeaten | 260 |
| 260 | 4/123, Quinmabe | 265 |
| 265 | 4/223, Ceenbion | 270 |
| 270 | 4/170, Tecexe | 275 |
| 275 | 4/194, Zalexe | 280 |
| 280 | 4/77, Biradi | 285 |
| 285 | 4/179, Atmaa | 290 |
| 290 | Enter4/197; trader and 7-second timer | 295 |
| 295 | 4/9, Dioris | 300 |
| 300 | 5/55, Estebiin HQ | 310; award EQ_XS_SWORD_MISSILE, CrippledAnni FALSE |
| 310 | Launch from HQ, strike Annihilator and destroy heat exchanger | 320 |
| 310 orother non320 | Annihilator's180-second wake timer | 330 |
| 320 | Annihilator dies | 340 |
| 330 | Annihilator dies | 350 |
| 340 or350 | Dock HQ | 360, branch-specific ending |
| 360 | Launch HQ | COMPLETED |

At 260/280, visits to 4/123 or4/77 spawn an Annihilator disc at [0,0,-18000], radius 10. Four-second steps change its appearance, cloak it and then remove it. Trader-message transitions depend on the current stage when the seven-second callback fires; keep that stage check when saving or leaving early.

The final HQ uses psu [0,0,0.1]. Before launch Thunder Child sits15,000 along the HQ position's normalized outward direction. Launch at 310 spawns replacement Thunder Child25,000 outward and the Annihilator40,000 outward, each radius 100, facing one another. It also adds three Society Cobras, three police and four Thargoids within1,500 of HQ. One nearby Thargoid is made to attack the player. Docking is forcibly refused at stages310/320/330 and hyperspace countdown is cancelled until the Annihilator death callback releases it.

The smaller final Sword calls dealEnergyDamage(1000,250), sets CrippledAnni TRUE, sends the target CRIPPLED and changes its appearance. This enables damage to the heat-exchanger subentity: subEntities[14] has its own death/damage callbacks. Before crippling, its damage callback restores energy 800. Its death sets320 and orders the Annihilator toward the planet. The source180-second timer starts on Annihilator spawn, not on missile impact. It sets330 only when the stage is not320; a successful heat-exchanger kill remains320. The briefing's approximate five-minute wording does not override180 seconds in code.

The main hull has energy 15,000/recharge 5,000, with numerous weapon-array and spike subentities. The Hive has energy 2,500/recharge 5/speed 75. Thunder Child has energy 1,200/recharge 13/speed 75 and 14 missiles plus its own weapons. Full source definitions preserve local transforms and role variants; a front weapon of NONE does not remove turret/subentity armament. Neither final ending pays an additional fee in the inspected callback; the100,000 success payment occurred at Lave.

## Source defects, project repairs and persistence

- Lave population assigns this.tharGroup, then reads unqualified tharGroup.leader. O08 OOJSScript compiles and executes against the script object, so that lookup resolves its property. The earlier isolated-function fixture produced a false ReferenceError; its replacement verifies successful Hive leader assignment and grouping. Do not add a purported source-bug repair for this valid object-scope access.
- The population reset compares status ===160 even though the state is the string STAGE_160. Repair the type/value mismatch and restore the correct system hooks after that battle.
- The interstellar route registers xsInterstellarSpaceWillRepopulate, but no matching function is defined in the inspected main script. Supply a project no-op repopulator that preserves the authored initial scene; label that as a repair choice.
- The attack fallback uses status == STAGE_3b as a comparison instead of assigning it. The ordinary Qutius arrival path already assigns3b; repair the fallback explicitly for alternate event order.
- Black Mamba startup loops for(var i in warheads) i.remove(true), invoking remove on an index string. Repair by looking up warheads[i] and removing that entity. This prevents a stale-warhead cleanup exception.
- Stage 1 credits 25,000 when displaying the HQ screen, before advancing the stage. Repeated opportunities can repeat this payment. Persist a one-time payment/briefing transaction in the project profile.
- Source pylon clearing sells equipment. The owner requires reusable storage: move replaced rounds/equipment into persistent storage without sale credit, then fit the two unique quest items atomically. A one-pylon ship needs a suitable hull; the universal one-missile minimum does not satisfy this two-pylon mission requirement.

Persist campaign stage, jump counter, CrippledAnni, quest item identities, accepted/paid screens and active encounter seed. Source this-fields such as timers, groups, Annihilator references, ambush state and pylon-clearing flags are transient. The project must serialize their meaningful remaining time/identities and reconstruct references on reload. Restrict special pickup callbacks to the corresponding quest instance/stage to prevent duplicated stale items regressing the campaign. Keep this repair separate from source behaviour.

Acceptance includes offer delay/refusal, both computer outcomes, missed wreck, ordinary/special ambush totals, forced interstellar jump and extraction, crystal/warhead destruction/NPC scoop, one/two free pylons, assembly and Hive collision, Lave success/failure branches, all second-circuit ports/timers, Sword impact versus target index14,180-second boundary, both finale endings, docking/jump release and save/reload at every encounter. The50 current fixtures establish selected source paths and blockers. Assembly collision, complete AI event order, O08 version compatibility, original runtime timing and released binary/asset parity remain open. This is R1 source core with explicit project repairs and R2 encounter runtime.
