# Active mission scope

Updated 13 October 2026 following the owner's latest instruction: **keep all research permissions and implement space missions; replace any planetside element with a handoff at a space station.** Preserve the original planetside sequence for reference only. This supersedes the earlier blanket exclusion of a mixed mission merely because its original story referenced a ground operation. This document and [machine-readable scope](data/implementation-scope.json) take precedence over earlier research documents and messages. Earlier exclusions of Frontier/First Encounters missions and all Elite Dangerous Operations remain in force.

## Removed from implementation

- Every Frontier: Elite II and Frontier: First Encounters mission, including JJFFE/FFE3D variants, F01-F16 and unfinished U01-U05. Generated families exclusive to those games are also removed.
- Every Elite Dangerous Operation D03-D09, including ship-only Operations.
- Guardian surface/SRV research assignments D01-D02.
- Other ground/on-foot combat, infiltration, terminal, heist, power-restoration, settlement, surface-mining and ground tip-off objectives. Removed exclusive family IDs are G01, G09, G10, G11, G15, G17, G18, G19 and G23; IDs are not reused.
- P01's dedicated Black Mesa on-foot text-adventure sub-mission. Its page/card/Trumble/stormtrooper mechanics are excluded from the project.

Excluded evidence may be retained and researched for reference; all existing research permissions remain in force, including necessary labelled estimates. The [archive](archive/README.md) preserves earlier evidence. An archived complete graph, old chat handoff or raw source record is not authorization to implement it. Apply the mission eligibility check below as well as the catalogue restrictions; a retained pack ID does not enable every mission in that pack.

## Retained

Original Elite computer/console missions, Oric assignments/tutorials and ship-based Oolite missions remain in scope. Elite Dangerous is limited to ship-based courier/freight/passengers/sightseeing/rescue, space combat/assassination/quotas, cargo liberation, space salvage, in-ship scans/installation interactions, asteroid mining, donations and anti-xeno ship combat. Per-family restrictions are in the JSON scope.

Briefings, dialogue, cargo collection and passenger loading at space stations remain ship-service interactions. Planetary-surface destinations, surface docking and atmospheric/ground operations are excluded. Merely naming a planet for navigation does not establish a planetside operation.

## Mission eligibility check

Evaluate individual missions within each campaign. Keep separately specified space missions without enabling their excluded siblings. Check every briefing, objective, optional branch, prerequisite and ending. For retained missions with a planetside element, replace that element with an explicitly mapped station handoff using the [handoff contract](station-handoff-specifications.md). Retain the surrounding space mission and its established branch outcomes. The original ground operation is research-only; no walking, SRV, atmospheric flight, surface landing or ground combat is implemented. An unresolved mapping remains disabled until its complete project specification passes this check. A campaign/package entry is a research inventory record, not blanket activation permission.

The previously planned P01 space-station supply replacement remains an explicit project adaptation. Its playable objectives and dependencies use station services; original Black Mesa adventure details remain reference-only. The same handoff approach is now authorized for other retained mixed missions, with each original-to-project transition recorded. This does not re-enable the separately excluded Frontier/First Encounters or Elite Dangerous Operations catalogues. Persist this distinction in mission availability and save migration so old state cannot activate an excluded branch.

Ship and alien research remains available, including Frontier-derived ship capabilities. The owner removed missions, without requesting deletion of ship data. The docked shipyard, 3D previews, linked comparison rotation, equipment transfer and persistent surplus storage requirements remain unchanged.

## P01 flight-only adaptation

Keep the ten assassination contracts and space revenge/escape scenes. At stage 53, docking at the Black Mesa space station opens a missile-supply confirmation. Require at least one pylon. On confirmation, store the commander's personal missile loadout, atomically fit up to min(10, missileCapacity) uniquely owned quest Gravitons and advance to 54. Cancel makes no change. The existing Angeriri main-station briefing then advances to 55 for the retained Balrog ship encounter.

This is an explicit project adaptation retained after the owner's clarification, not a claim about original Assassins Guild behaviour. The playable supply/finale specification must be self-contained and contain no playable planetside-operation requirement. Preserve the flight escape/finale scene only; implement no adventure pages, card search, Trumble puzzle or stormtrooper encounter. At completion, remove only quest Gravitons by identity and restore compatible stored personal rounds; any surplus stays stored. A hull switch cannot duplicate the supply grant or erase the quest loadout.

## Readiness and handoff

The active catalogue contains 89 canonical inventory entries, including 48 expansion-pack discovery records. That is not 89 fully specified playable missions. Earlier counts of 128 include the 39 now-excluded identities. Keep expansion sub-contracts nested under their canonical campaign.

Before implementing from an earlier handoff, read this scope first. Final research readiness still requires completing the retained campaigns and numerical project profiles; excluded missions are reference-only and no longer implementation blockers or future game tasks. Further reference research remains authorized. Never re-enable an excluded mission merely because its archived source is well documented.
