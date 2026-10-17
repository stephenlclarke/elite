# Incremental mission implementation

Research readiness, receipt and playable implementation are separate. The three currently playable campaigns are now bundled TOML packs; the [mission-pack framework](MISSION-PACKS.md) also loads validated external content without rebuilding. This does not enable any queued research packet. Apply the [research implementation scope](research/implementation-scope.md) v4 and station-handoff contract. Frontier/First Encounters missions, Elite Dangerous Operations and playable surface stages remain excluded. Preserve all ship and alien research.

## Current development status

As of 17 October 2026, the new engine foundations are implemented: Lua packs, saved instances, dialogue and choices, milestone and completion receipts, linked campaigns, physical encounter and equipment adapters, repeatable contract boards, pledges, courier custody and mission calendars. The complete planned engine is not declared finished. Full combined validation, remaining integrations and release publication are separate outstanding gates.

Three campaigns are bundled: Constrictor Hunt, Thargoid Plans and Blackjack's Bullion. The development app also discovers generated courier jobs at startup. The other Lua examples under `docs/mission-packs/` are optional content, not automatically installed campaigns. Research readiness or a completed source branch does not make a mission available in the game.

Native RRS station/board integration, its read-only Gallery projection and P30 courier scenario 2 are now composed in the isolated release source `ddcdb969a9dbf945309582cf7cee0ddf3f4ea087`. Compilation and runtime validation remain pending. The independently reviewed raw legacy save guard is source-composed at `fcee2a0e03b8db99d63ae7f620451c3872cb8ed1`; its seven authored cases still require execution before release. Scenario 2a and the wider Rescue Stations families remain queued. No RRS mission is claimed playable by this status update. Other queued packets below are still outstanding. Historical test counts in delivery rows describe their original delivery, not current whole-app acceptance.

| Packet | Receipt | Implementation |
| --- | --- | --- |
| P05 Blackjack's Bullion 1.2.9 | Received 13 October 2026; complete bounded space/station specification | Implemented in [PR #4](https://github.com/stephenlclarke/elite/pull/4); 155 tests pass; 94.91% overall coverage, clean sanitizers and 0 leaks; PR records merge status |
| P22 Localhero I 1.05 | Received 13 October 2026; 31-assignment profile and 58 selected source checks | Queued; not yet playable |
| P16 GalCop's Most Wanted 0.16 / BountySystem 0.19 | Received 13 October 2026; repeatable tracking profile and 31 selected source checks | Queued; not yet playable |
| P21 LinkG7 0.1 | Received 13 October 2026; space-trial profile, 16 selected source checks and explicit midpoint repair | Queued; not yet playable |
| P32 Runner G5 | Received 13 October 2026; isolated challenge-commander profile and finish-boundary checks | Queued; not yet playable |
| P47 Victim11 | Received 13 October 2026; custody branches, saved failure ending and source battle profile | Queued; not yet playable; depends on actual P01 completion |
| P28 Oo-Haul 2.0 | Received 13 October 2026; generated escort contracts and explicit edition repairs | Queued; not yet playable |
| P44 Trident Down | Received 13 October 2026; four-way bounded profile | Queued; not yet playable |
| P46 Vector services | Received 13 October 2026; Benus/PAD, Arn, Richmans World, flight inspection, Areidis terminals and specialist crystal trade | Queued; not yet playable |
| RRS Contract Board | Received 13 October 2026; explicit waystation/HQ capability adapter; fifteen research-ready profiles, only implemented/enabled safe profiles may be offered | Station/board adapter and Gallery source composed in isolated release source; raw save authority guard composed; compilation and runtime validation pending; no board or mission claimed playable |
| P30 Rescue Stations blackbox 3/3a | Received 13 October 2026; two isolated recovery profiles | Queued; not yet playable |
| P30 Rescue Stations personnel 4 | Received 13 October 2026; pilot pickup/return, fitted berth and saved deadline profile | Queued; not yet playable |
| P30 Rescue Stations captured pilot 4a | Received 13 October 2026; slaver-base rescue, unique captives, medical receipts and reserved fitted berth profile | Queued; not yet playable |
| P30 Rescue Stations Astromine 4b | Received 13 October 2026; docked agent/captive-craft transport, strict timer and wormhole receipt profile | Queued; not yet playable; actual board, cabins, AI and transport receipts remain dependencies |
| P30 Rescue Stations emergency freighter 5 | Received 13 October 2026; accepted-home emergency escort, physical docking, finite actors and deferred bonus receipts | Queued; not yet playable; 5a and 6 are received; 6a is now received |
| P30 Rescue Stations returning Arafura 5a | Received 13 October 2026; real home/boat escort, timer and crew/custody profile | Queued; not yet playable |
| P30 Rescue Stations materials transfer 6 | Received 13 October 2026; sealed 1t cargo, actual waystation receipt and accepted deadline profile | Queued; not yet playable |
| P30 Rescue Stations medical supplies 6a | Received 14 October 2026; orbital pickup/hospital delivery, fixed physical consignment and saved fleet/timer receipts | Queued; not yet playable |
| P30 Solar Lab 2b | Received 13 October 2026; bounded lease, thermal/recovery and refund profile | Queued; not yet playable |
| P30 Rescue Stations couriers 2/2a | Received 13 October 2026; two isolated document delivery profiles | Scenario 2 source composed with native RRS and Gallery; raw save authority guard composed; compilation and runtime validation pending. Scenario 2a queued. Neither claimed playable |
| P30 Rescue Stations escort 1/1a/1b | Received 13 October 2026; three isolated bounded repair/escort profiles | Queued; not yet playable; remaining P30 families are research-open |

The complete research collection and remaining mission backlog are not declared finished. A source fixture count is not a native runtime test count or proof of original-engine parity.

The [qualified validation ledger](WHOLE-APP-REMEDIATION.md) distinguishes source composition, historical focused passes, failed full gates and current release acceptance. The research inventory contains 89 entries, which are not 89 implemented missions.
