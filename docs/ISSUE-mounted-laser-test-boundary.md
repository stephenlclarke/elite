# Mounted-laser equipment test uses an obsolete Return route

Official CI593 on0482eb88a3c549b60bbe382bb21e7d8715ef1bc7 reports three issues in `laserMountDamageRateAndEmptyViewsUseTheirOwnAuthoritativeEquipment`: target energy100 instead of50 after each interval, and no heat despite a fitted laser. The expected50 identifies the left-mounted Mining Laser branch; pulse, beam and empty-view cases produced no issue in this record.

The test intends to verify each fitted mount's own damage, cadence and heat. It instead submits held Return while `selectedFlightTool` remains Combat Laser. The maintained input router explicitly refuses a mining mount in combat mode. The separately selected Mining Laser is a forward work tool that can emit only at a verified, unoccluded rock; a ship is not an eligible mining target. Letting combat Return discharge that mining mount at a ship would contradict the approved tool semantics.

Retain the original fitted equipment and50-damage mining oracle. Exercise the maintained native mounted firing kernel directly, while neutral ticks advance its unchanged cooldown intervals. Add an explicit held-Return regression to preserve the refusal that exposed this stale test boundary. No weapon/input production change is justified by this evidence.
