# Blackjack's Bullion mission profile

This native adaptation selects Rustybolts' Oolite Blackjack's Bullion 1.2.9, packet P05, with saved profile `P05-1.2.9-station-v1`. It is an optional expansion campaign alongside the two BBC naval missions, not an additional historical BBC Executive mission. The implementation follows the locally maintained scope v4 and station-handoff contract. Original briefing prose, scripts, models and textures are not bundled.

## Pinned evidence

The [author's listing](https://wiki.alioth.net/index.php/BlackjacksBullion_OXP) identifies the campaign. The recovered [public author archive](https://app.box.com/s/ed1c019b87b021ee54db), file 2389064390, was accessed on 13 October 2026. Archive SHA-256: `d3ae65a6bfca690d9154ca7890efa707fb2f0a03d3d14e911f9e16cc9c78bbe8`. The source scripts identify Rustybolts and permit reuse with "Do with as you wish". Text here and in the game is independently worded.

Paths below are relative to `galaxy 2, Blackjack's Bullion 1.2.9.oxp/` in that archive.

| File | SHA-256 |
| --- | --- |
| `Scripts/blackjacks.js` | `2cd0b78bc4f0aa046dba3428e03aa494adb2fe1d456fa32fb714fea7ead42dbb` |
| `Scripts/blackjacks_bolts.js` | `c7238194732341e2f320f12fbbe9dcf1f39cbb33ad825662ec500d00ed9930bb` |
| `Scripts/blackjacks_witness.js` | `b1e98e2d680f3bdaf4690a3cda99f836b100b2532fe42f137f4cf88f82668143` |
| `Config/shipdata.plist` | `12ef01d6fb979959d6cab14db1b76a82441a3cb9927db0b382dbfd6a15cb0981` |
| `Config/missiontext.plist` | `cc2e6071f18ff4f2dc8235d3a5367a8f8765e70f83dde94c820edcda0a5010ef` |

The independently maintained local research contains the complete recovered member inventory and seven selected callback fixtures. Those source checks establish the selected rules; they are separate from native runtime tests and original-engine parity.

## Campaign rules

All locations are in player Galaxy 2 (stored index 1); system IDs are zero-based. No combat score, legal-status gate or deadline is added.

| Saved stage | Trigger | Result |
| --- | --- | --- |
| 0 -> 1 | Dock at Telace 241 main station | Automatic enrolment; find Commander Bolts at Gerebied 88 |
| 1 -> 2 | Unique Bolts destroyed at Gerebied, by any killer | Directly earn 20 kg gold once; report at any Galaxy 2 main station |
| 2 -> 3 | Confirm station report | Proceed to Tegete 233 |
| 3 -> 4 | Confirm Tegete main-station pickup with one free tonne | Load one marked mission firearm |
| 4 -> 5 | Confirm Ceinerxe 127 main-station handoff | Consume the marked firearm; wanted level at least 64; find witness at Edater 99 |
| 5 -> 6 | Unique witness destroyed at Edater, by any killer | Report at Esdi 67 |
| 6 -> 99 | Confirm Esdi main-station debrief | Award exactly 9,500 CR and clear bounty once; terminal completion |

Initial contact enrols immediately, matching the source. Continue or Back closes its explanation. Later transfers require explicit Confirm; Back has no transfer effect. B reopens an eligible station contact. K shows contextual help. Station messages defer to an active BBC naval briefing. Saving/loading never confirms a handoff or pays a reward.

Gold uses native kilogram storage, so a hold full of tonne commodities does not block it. An extreme numeric storage limit defers the already-earned gold to an explicit station collection instead of losing or duplicating it. The final payment likewise waits if it would exceed the account limit. Each transfer commits item, stage and once-only flags together inside GameRuntime, without an intervening actor suspension.

## Custody and persistence repairs

These deliberate repairs follow the research specification and differ from the recovered scripts:

- The firearm is reserved mission cargo. Manual sales and auto-trade retain its one-tonne quantity; ordinary firearms in excess remain tradable. Ceinerxe consumes only that marked quantity. Escape-pod recovery preserves it, and invalid saves with missing custody are rejected. The source left the weapon behind after the robbery.
- Wanted stages use `max(current, 64)` in Galaxy 2. The source repeatedly overwrote bounty with exactly 64, reducing unrelated offences. Final clearance still happens once, as in the source; later offences survive repeat visits.
- Bolts and witness have persistent UUIDs, health, finite missiles, laser cooldown and station-relative position/orientation. Re-entry restores the same actor without healing or replenishing ammunition. A target outside the local bubble can reappear on the source-system lane with its saved identity and resources. Living range removal is not a kill.
- The witness callback requires the active unique witness, correct galaxy/system and stage 5. The source callback was ungated and could reopen a finished campaign. Repeated deaths, arrivals, confirmations and reloads cannot repeat rewards.

Existing personal equipment, four laser mounts and player missiles survive station transfers. This project does not yet have a general shipyard/storage system. A capacity check is exposed for future hull changes; this release does not claim a playable hull-switch workflow. All independently maintained ship and alien research remains intact.

## Encounter and presentation boundary

Both targets retain energy 300, recharge 4 per second, speed 390, forward pulse damage 25, three finite missiles and ECM capability. Bolts' source cargo capacity is 55 tonnes and spawned bounty 64 CR; the witness's capacity is 5 tonnes and bounty zero. Player-attributed kills alone earn ordinary combat points and destruction bounty, while either killer satisfies the campaign objective.

The native adapter places first encounters at lane fraction 0.1 and uses the game's pulse interval, pursuit steering, missile tactics, ECM and collision rules. It does not reproduce Oolite's pirate AI or cargo generation. S.T.E identities and orange/green colour are shown using the existing Cobra mesh; original S.T.E geometry/textures remain research data. No walking, station interior combat, surface stage, additional stolen-cash reward or new robbery minigame is added.

The Gallery adds seven chronological milestones driven by committed mission state. Optional travel and clue visits do not invent progress. The native station panel uses the original-style font at responsive window sizes.

## Validation

Native regressions cover exact seeded system names, automatic enrolment, all seven transitions, any-killer objectives, wrong station/galaxy/identity/stage, Back, stale offers, main-station binding, full holds, reserved firearms, auto-trade, escape recovery, old-save migration, corrupted state rejection, persistent health/ammunition/pose, living range removal, final account limits and once-only gold/payment/clearance. AppKit tests exercise Retina frame conversion, contact mouse events and contextual help. The leak lifecycle probe includes station contacts, Gallery browsing and persistent mission encounters. `make ci` remains the coverage, thread, address and leak acceptance gate.

## Mission-pack implementation

Campaign content and progression are maintained in `Sources/EliteCore/Resources/MissionPacks/` using the same validated [TOML schema](MISSION-PACKS.md) as external packs. Existing encounter/combat/custody primitives remain in Swift; legacy saved stages and unique targets retain their identities. Installing a new supported pack does not change this campaign or replay its rewards.
