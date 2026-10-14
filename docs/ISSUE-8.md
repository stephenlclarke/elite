# Mission packs and signed macOS distribution

Adding a mission currently requires editing and rebuilding Swift. Existing campaigns need the same data format as external packs, with stable progress, original scenario behaviour and bounded engine capabilities. Commander saves must survive missing or changed content without losing cargo or repeating rewards.

Implement validated TOML packs, explicit legacy-state adapters, atomic transactions, deterministic events, a visible installation action, a schema and a playable external example. Preserve the BBC removal/wrapping rules and Blackjack identity/custody/once-only rewards. Keep unsupported research campaigns unavailable. Validate the actual native install/flight/delivery/reload flow and the full quality gates.

Ship a Release universal macOS ZIP signed with Developer ID, along with its checksum and source/signing/notarization manifest in the repository. Source checkpoint and binary publication commits must be distinguishable. See [PR-8.md](PR-8.md) for implementation and validation.
