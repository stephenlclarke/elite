# Historical behaviour checklist

XYZZY's Right-On Commander version uses the 6502 Second Processor Executive build as its historical reference, retaining the original-style font by user preference. This checklist distinguishes functional implementation from historically verified parity.

| Area | Current implementation | Evidence / remaining work |
| --- | --- | --- |
| Galaxy | Eight seeded 256-system galaxies | Lave, Zaonce and Diso fixtures and repeatability tests |
| Markets | Original economy, gradient and fluctuation calculations | Exhaustive bounds over eight economies and 256 fluctuation values |
| Commander | Jameson with standard Cobra Mk III; XYZZY gives Clarke maximum hardware | Intentional user-requested defaults replacing Executive Firebud; JSON save format rather than DFS commander files |
| Controls | Number keys, keyboard or held trackpad flight, weapon and drive keys; Command-P pause | Two fingers steer, one brakes, three accelerate; release centres the yoke and cruises. Native adapter, continuous-input and menu tests; physical three-finger delivery depends on macOS gestures |
| Graphics | Original logical layout and bitmap font; native-resolution geometry, clipped wireframes, hidden faces, scanner and bars | Retina drawing, smooth planet/cockpit curves and persistent subpixel stars are intentional user-requested improvements; planar convex hulls, complete silhouettes across 7,200 orientations and unclipped title rotations are tested; independently drawn meshes and glyphs need original-frame comparison |
| Intro demo | XYZZY scroll then rotating Right-On Commander title | Independent short script rather than the full original text and sequence |
| Executive options | Unlimited range and fuel in XYZZY; optional Mac speech | Intentional relocation of paused @ options to secret keys 4/5; travel and persistence tests; speech timbre differs from Watford hardware |
| Trading | Buy/sell, stock/cash/capacity checks, equipment purchases | Transaction and resource-boundary tests |
| Travel | Fuel accounting, countdown, eight galaxies, mass lock and docking computer | Navigation tests; physics and docking are simplified |
| Combat | Lasers, shields/energy, missiles, ECM, bomb, escape pod, ranks | Deterministic combat tests; historical tactics, missile flight and legal pursuit remain simplified |
| Ship roster | Eight independent hull categories plus source-derived Constrictor and Thargon geometry; Executive limit of 18 simultaneous objects | Full original ship roster and blueprint-by-blueprint parity pending |
| Secret additions | Unlimited resources; destination/economy/government-aware auto-trading including illegal goods; white/colour wireframe and shaded-panel display selector | Dedicated tests, old-save compatibility and opaque clipped faces; intentional user-requested extensions |
| Player help | K / Command-K opens a paged guide for the current screen and pauses the simulation | Flight, station, trading, equipment, charts, pause, title/demo and XYZZY context checks; intentional addition |
| Missions | Executive Constrictor Hunt and Thargoid Plans, source TP flags, thresholds, clues, rewards and persistence | Source-backed boundary/workflow tests; removal-completion and register-wrap quirks retained; [mission profile](docs/BBC-EXECUTIVE-MISSIONS.md) separates implemented rules from remaining engine/binary parity |
| Descriptions | Economy, government, population, technology, productivity, radius; Executive notices at Lave/Riedquat | Full goat-soup descriptions and exact Executive overrides pending |
| Sound | Synthesised native square-wave/noise effects and optional native speech | Deterministic WAV tests; original sound timing and speech hardware not reproduced |
| Runtime | Swift actor simulation, main-actor window/input/presentation, value snapshots | Concurrent-command tests, sanitizers, lifecycle leak probe and native smoke check |

A green quality gate measures code quality and test coverage; it is not evidence of exact original-game fidelity. Do not label an approximation as verified historical parity.
