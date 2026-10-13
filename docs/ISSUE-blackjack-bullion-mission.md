# Add the first incremental expansion mission

Research packet P05 supplies a recovered, bounded Blackjack's Bullion 1.2.9 campaign. The game currently exposes only the two BBC naval missions. Implement this packet without presenting other delivered research as playable or changing the original BBC rules.

Required behaviour: Galaxy 2 automatic Telace contact, unique Bolts and witness objectives, direct 20 kg gold, reserved one-tonne firearm, explicit orbital Confirm/Back transfers, wanted-state policy, final 9,500 CR payment and one-time bounty clearance. Save target identity, damage, finite ordnance, custody, stages and transfer receipts. Back, wrong stations, repeat deaths and reloads must not duplicate changes. Preserve personal equipment and all independently maintained research.

Validation includes campaign and persistence regressions, native contact/help/Gallery checks, coverage, both sanitizers and the leak lifecycle probe. Document the researched repairs and existing native AI/mesh limitations. Later delivered packets belong in the implementation queue.

Implementation: [PR-blackjack-bullion-mission.md](PR-blackjack-bullion-mission.md).
