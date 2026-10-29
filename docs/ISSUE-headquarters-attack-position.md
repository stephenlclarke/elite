# Headquarters destruction fixture enters main-station security combat

Main e2910137 run40898297625 attempt2 failed one normal method with three related issues: the player died before headquarters destruction, so the station and tombstone assertions failed. The full inventory contained3403 methods with six declared opt-in skips; leaks and Sonar were not reached. The runner closed cleanly, and the original failure evidence remains preserved.

The existing retained PLAYER_COMBAT_FATAL event identifies a security police pulse laser in the actual G04-S149 visit at physical time184.4. This is an observed combat death, not a memory, solar or allocator failure. The old attack fixture chose a model face normal from a fresh world-dependent headquarters orientation and could place its stationary, undefended player inside the original main-station security pursuit boundary during the long volley.

StationSecurity checks actual canonical player distance against20,000 units on each target selection. Correct the experiment's initial observation point while retaining original station geometry, every other world actor, finite player health, actual damage/legal/security mechanics and the full missile/destruction/persistence assertions. No lucky world identity or disabled hazard is acceptable.
