# Install the selected Commies hull definitions and Transporter hold correction

The received 14 October research packet maps Convict Miner Minnow, Ray Mk I/Sunray and Military Stingray/Ray Mk II to stable IDs SH168, SH169 and SH170. Their source records did not install native catalogue definitions. The separately approved Transporter correction replaces the estimated zero player hold with the selected Oolite NPC-derived 12-tonne adaptation.

## Source changes

The three new authoritative TOMLs retain the exact selected Commies 2.20 meshes, imported with the existing DAT reader's Z reflection and winding/UV conversion. The source model hashes are:

| ID | Selected DAT | SHA256 |
| --- | --- | --- |
| SH168 | commies_comminer.dat | fa695f20d02b20b4e76f827b0667da4dc1bb5f9b1206fcbaca1f5e1ecf23c369 |
| SH169 | commies_ray.dat | ac6723c2e1b49e12a031f6c5deed687f52e86cbd63cfa72df2abad2028152936 |
| SH170 | commies_rayii.dat | a29d506bf62198fdacb220b6086f2bd2983134137802a4e1cac0f88442b0bd1c |

The source archive is Commies 2.20, 35,340,515 bytes, SHA256 `09d478852cf2485e3a1e8be2ebca9d8771ea13af08ac977010a7c07fb8a42e4a`. Its manifest credits Amaranth, Dr. Nil, Eric Walch, Norby, phkb and GearsNSuch. README 2.18 attributes replacement Ray and derivative graphics to GearsNSuch; the selected records do not establish an individual Minnow modeller. Original README/manifest text, member hashes, archive identity, selected source definition and variant keys are embedded in each TOML's custody. Inspectable attribution profiles retain CC BY-NC-SA 3.0 terms, the licence link and the native adaptation notice. Native default liveries are explicitly project-authored under MIT. Source face colours and texture names/UVs are archival; texture pixels are not bundled or rendered.

The received `PROJECT-COMMIES-SELECTED-SHIPS-v1` mechanics supply the initial native values under the existing [Cobra calibration and economics](SHIP-FILES.md). All 13 source variant dictionaries remain separate reference profiles, including NPC fuel, weapons, holds, AI and legal roles. The player conversion does not substitute for Astromine's NPC configurations. SH165–SH167 and existing native hull mappings remain untouched.

SH128 changes exactly `game.cargo` and its current common-refit `cargo_tonnes` / `usable_cargo_after_fit` fields to 12. The latter two explicitly identify the borrowed native NPC capacity and player adaptation. Historical GBA estimated zero remains a historical profile. Flight, price, geometry, fitting allowance, crew and all unrelated data remain unchanged.

## Mechanics boundary

The new hulls use the existing carried-fit exchange. Source first outfits and missile stocks remain reference templates; choosing or loading a hull does not grant them. Sunray's source-standard berth and five-tonne first-fit remaining hold do not implement a native cabin. The common base hold remains ten tonnes. Crew one and equipment budgets eight/ten/eleven retain their estimate labels.

Military Stingray's source multiply mode has two emitters controlled by one forward weapon. Its reference profile does not create two inventory weapons, a second facing or functioning dual-ray behavior. Native cabin/first-acquisition outfit, equipment-unit budgets, surplus equipment storage, multi-emitter primitives and associated mission capability admission remain separate engine work. No Game, Commander, renderer, NPC mission pack or unsupported TOML game field is added in this packet.

## Validation status

Source preparation only: the new regression suite is **uncompiled and unexecuted**. Five authored methods declare nine cases covering the selected calibrated values, stable identities, exact mesh counts/envelopes/source appearance, 13 distinct source roles, source cabin/crew/emitter boundaries, and Transporter's actual Commander hold admission at 12 versus 13 tonnes. Python TOML parsing, bounded source hash/custody checks, strict Swift formatting and whitespace checks are the permitted source checks; they do not establish runtime or renderer correctness.

Authoring used `python3 /tmp/elite-mc1-author-commies-ships.py` with the pinned local source archive and DAT files. That source-only staging script called the existing `dat_mesh`, `field`, `default_livery` and `write_ship` functions, then retained the resulting self-contained TOMLs. It did not run media generation or a native binary. The protected research files were read only.

The central integrator must run the focused suite, `make ships`, `make ships-check` and `make ci` under an assigned validation lease, reconcile generated catalogue/provenance and renderer-produced GIFs, obtain an actual clean `@codex review` on the final PR head, then merge. Existing generated documentation/media deliberately remains pending that workflow. Sonar publication belongs only to a committed main branch using its exact SHA.
