# Historical behaviour checklist

The requested target is the 6502 Second Processor Executive version, retaining the original-style font by user preference. This checklist distinguishes functional implementation from historically verified parity.

| Area | Current implementation | Evidence / remaining work |
| --- | --- | --- |
| Galaxy | Eight seeded 256-system galaxies | Lave, Zaonce and Diso fixtures and repeatability tests |
| Markets | Original economy, gradient and fluctuation calculations | Exhaustive bounds over eight economies and 256 fluctuation values |
| Commander | Firebud, 100 million credits, fitted equipment | Executive default tests; JSON save format rather than DFS commander files |
| Controls | Disc function keys, held pitch/roll/throttle/laser, weapon and drive keys | Native NSEvent translation tests; number keys 0-9 replace function keys by user preference |
| Graphics | 256-square bitmap renderer, clipped wireframes, hidden faces, scanner and bars | Deterministic rendering, closed-mesh/outward-normal regression tests and antialiased subpixel ship strokes; independently drawn meshes and glyphs need original-frame comparison |
| Executive demo | Automatic wireframe/demo scroll then rotating title | Independent short script rather than the full original text and sequence |
| Executive options | Pause/@ infinite range and fuel; optional Mac speech | Travel and persistence tests; speech timbre differs from Watford hardware |
| Trading | Buy/sell, stock/cash/capacity checks, equipment purchases | Transaction and resource-boundary tests |
| Travel | Fuel accounting, countdown, eight galaxies, mass lock and docking computer | Navigation tests; physics and docking are simplified |
| Combat | Lasers, shields/energy, missiles, ECM, bomb, escape pod, ranks | Deterministic combat tests; historical tactics, missile flight and legal pursuit remain simplified |
| Ship roster | Eight independent wireframe hull categories; Executive limit of 18 simultaneous objects | Full original ship roster and blueprint-by-blueprint parity pending |
| Secret additions | Unlimited resources; destination/economy/government-aware auto-trading including illegal goods | Dedicated tests; intentional user-requested extensions |
| Missions | Not implemented | Constrictor and Thargoid Plans scripts pending |
| Descriptions | Economy, government, population, technology, productivity, radius; Executive notices at Lave/Riedquat | Full goat-soup descriptions and exact Executive overrides pending |
| Sound | Synthesised native square-wave/noise effects and optional native speech | Deterministic WAV tests; original sound timing and speech hardware not reproduced |
| Runtime | Swift actor simulation, main-actor window/input/presentation, value snapshots | Concurrent-command tests, sanitizers, lifecycle leak probe and native smoke check |

A green quality gate measures code quality and test coverage; it is not evidence of exact original-game fidelity. Do not label an approximation as verified historical parity.
