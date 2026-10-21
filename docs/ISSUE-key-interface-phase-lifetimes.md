# Gameplay key storage overlaps already-handled gallery navigation

The exact thread-sanitized binary stopped on a guard-page access while the original unstarted-preview test processed Return through Game.key, interfaceKey, gallery navigation and catalogue lookup. The exact binary audit found six Game-sized stack reservations in Game.key before interfaceKey. Those buffers belong to later key processing even when interfaceKey completely handles the input.

The catalogue closures were separately verified to borrow Game rather than allocate the suspected whole-game copies; their uncommitted rewrite was withdrawn. Separate interface dispatch from the entire later gameplay key phase while preserving every original case and test. See [implementation](PR-key-interface-phase-lifetimes.md).
