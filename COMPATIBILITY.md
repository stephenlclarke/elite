# Historical behaviour checklist

XYZZY's Right-On Commander version uses the 6502 Second Processor Executive build as its historical reference, retaining the original-style font by user preference. This checklist distinguishes functional implementation from historically verified parity.

This is a historical gameplay comparison, not a backward-compatibility commitment. The user's 19 October 2026 delivery decision makes existing saves disposable and waives predecessor save/content/API/namespace compatibility. Current-format validation, round trips and durable transactions remain required; older migration descriptions below record existing or historical behavior rather than a delivery requirement.

| Area | Current implementation | Evidence / remaining work |
| --- | --- | --- |
| Galaxy | Eight seeded 256-system galaxies plus a separately discovered PLUGH port per galaxy | Lave, Zaonce and Diso fixtures and repeatability tests |
| Markets | Original economy, gradient and fluctuation calculations | Exhaustive bounds over eight economies and 256 fluctuation values |
| Commander | Jameson with standard Cobra Mk III; XYZZY gives Clarke maximum hardware | Intentional user-requested defaults replacing Executive Firebud; finite 1M CR XYZZY start and independent four-mount laser loadout; JSON save format rather than DFS commander files |
| Controls | Number keys, keyboard or held trackpad flight, weapon and drive keys; Command-P pause | Two fingers steer, one brakes, three accelerate; release centres the yoke and cruises. Native adapter, continuous-input and menu tests; physical three-finger delivery depends on macOS gestures |
| Graphics | Responsive full-width flight view and compact original-style bitmap font; shaded rotating startup ships, native-resolution geometry, clipped wireframes, hidden faces, expanded scanner and capped bars | Retina drawing, smooth cockpit curves and persistent subpixel stars are intentional user-requested improvements; planar convex hulls, complete silhouettes across 7,200 orientations and unclipped title rotations are tested; independently drawn meshes and glyphs need original-frame comparison |
| Intro demo | XYZZY scroll then rotating Right-On Commander title | Independent short script rather than the full original text and sequence |
| Executive options | Optional fuel replenishment and Mac speech in XYZZY; all jumps obey tank, fuel and nav limits | User revisions remove unlimited distance and cash; 1M CR initial grant and old-save migration tested; speech timbre differs from Watford hardware |
| Trading | Buy/sell with consistent commodity-category colours, explicit availability, grouped equipment and four laser fittings | Transaction, mount persistence, stock/cash/capacity and responsive layout tests |
| Travel | Fuel accounting, countdown, eight galaxies, mass lock and docking computer | Navigation tests; physics and docking are simplified |
| Combat | Lasers, shields/energy, missiles, ECM, bomb, escape pod, ranks | Deterministic combat tests; historical tactics, missile flight and legal pursuit remain simplified |
| Ship showroom | Read-only 167-identity catalogue, 158 labelled refits and 56 corresponding source meshes | Source units and unknown facts retained; current player hull remains native Cobra; [model attribution and limits](docs/SHIP-SHOWROOM.md) |
| Ship roster | Eight independent hull categories plus source-derived Constrictor and Thargon geometry; Executive limit of 18 simultaneous objects | Full original ship roster and blueprint-by-blueprint parity pending |
| Max equipment | XYZZY Naval lasers, Military targeting and Capital shields; earned Capital reward at Elite rank | User-requested extensions; Naval damage is a documented prototype default, shield multipliers/prices follow user instructions; no rank grant from XYZZY |
| Secret additions | Unlimited missiles/cargo and optional fuel replenishment; finite cash; destination/economy/government-aware auto-trading including illegal goods; white/colour wireframe and shaded-panel display selector | Dedicated tests, old-save compatibility and opaque clipped faces; intentional user-requested extensions |
| Assistance | XYZZY AUTO target tracking, full station docking and automatic ECM with ordered speech | Intentional native prototypes; full geometry-checked docking; target-cycle, safety, phase/rate and actual ECM attribution tests |
| Gallery | Read-only catalogue of the two BBC missions and Blackjack's Bullion, with chronological milestones | All TP stages, old saves, responsive layout and frozen-flight restoration tested; research inventory is separate from playable missions |
| Scoops | Maximum hardware includes Fuel Scoops; lower-nose collection of native cargo and inactive Thargons | Native canisters contain Food; solar fuel collection and source cargo-generation parity remain unimplemented |
| Player help | K / Command-K opens a paged guide for the current screen and pauses the simulation | Flight, station, trading, equipment, charts, pause, title/demo and XYZZY context checks; intentional addition |
| Missions | Executive Constrictor Hunt and Thargoid Plans, source TP flags, thresholds, clues, rewards and persistence | Source-backed boundary/workflow tests; removal-completion and register-wrap quirks retained; [mission profile](docs/BBC-EXECUTIVE-MISSIONS.md) separates implemented rules from remaining engine/binary parity |
| Expansion campaign | Blackjack's Bullion 1.2.9: seven stages, direct gold, reserved firearm, wanted state and final payment | Persistent unique targets and Confirm/Back station transfers; [source profile](docs/BLACKJACK-BULLION.md) labels repairs, Cobra-mesh approximation and simplified AI |
| Descriptions | Economy, government, population, technology, productivity, radius; Executive notices at Lave/Riedquat | Full goat-soup descriptions and exact Executive overrides pending |
| Sound | Synthesised native square-wave/noise effects and optional native speech for gameplay notification events | Event cursor/queue/preference tests and deterministic WAV tests; original sound timing and speech hardware not reproduced |
| Runtime | Swift actor simulation, main-actor window/input/presentation, value snapshots | Concurrent-command tests, sanitizers, lifecycle leak probe and native smoke check |

A green quality gate measures code quality and test coverage; it is not evidence of exact original-game fidelity. Do not label an approximation as verified historical parity.

Navigation computers, counted fuel storage, grouped equipment, route estimates and three chart rings are intentional native extensions with save and boundary tests, rather than historical Elite equipment parity.
