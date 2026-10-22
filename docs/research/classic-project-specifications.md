# Project parameters for remaining original Elite missions

These [five bounded profiles](data/classic-project-profiles.json) fill the remaining PC-PLUS C07 and Archimedes C09-C12 gaps using the owner's permission for necessary labelled estimates. They preserve reported objectives and identify unknown numerical values, surrogate hulls and project choices separately. They do not establish original binary parity and do not replace the recovered ST, GBA or Oric profiles.

## Route bindings

The [route derivation](data/classic-route-derivation.json) independently runs the original GBA name-generator functions and the current project's Universe generator. All eight named bindings agree. For Genesis, galaxy 0 gives Razaar167, Ordima236 and Xeaan80. For the medicine example, galaxy 5 gives Zadiqu170, Beored171, Vebereti172, Orria173 and Vereinat174. These establish classical chart bindings, not ARC executable mission selectors. Medicine uses the acceptance galaxy's indices; its example names must not be hardcoded in every galaxy.

## Filled profiles

| Mission | Retained reported behaviour | Necessary project parameters |
| --- | --- | --- |
| C07 Stolen Police Ship | Identify/destroy a stolen police craft and receive payment. | Viper surrogate, unique target, score 128 gate, deterministic target index, pulse/one missile, issuer hand-in and 6,000-credit fee. No unsupported deadline is added. |
| C09 Genesis Capsule | GalFam route, pickup deduction150, capsule jettisoned last, low directed release, planet improvement and 500-credit reward. | One-tonne capsule; release altitude <=500 m and inward heading dot >=0.98; target-port docking pays once. Source threshold report is >550 kills and >1,200 credits. |
| C10 Zartid III | System 116, five Mamba escorts, retreat/regenerated shields, more reinforcements and failure after >15 dockings; yaw boosters. | Unidentified blue wing-shaped craft uses a labelled Asp surrogate; energy 1,024, shields512 each, speed 360, military/beam lasers/four missiles; reinforcement interval120 s, cap 20 extra; yaw multiplier1.5. |
| C11 Zurid Pino | Warning/followup score gates, system%5==1, encounter government<3, scanner-concealed Cobra III with eight missiles; autolock reward. | Durability/speed/weapons, retreat threshold, missile interval, spawn/hand-in events and explicit autolock range/cone. Scanner concealment does not automatically mean an invisible rendered hull. |
| C12 Medicine Run | Four constituent stops plus mixer, branching clues, Paredon reaction after shield loss/jolt, escape retention, inoculation and 2,000 credits. | Ingredient identities/assignment/one-tonne lots, clue tree, partial deposits, heat growth10/s/death100 and seeded 0.5 jump-quench chance. Unknown chemical names use neutral placeholders. |

Every active instance freezes its routes/parameters, unique target/item identities, timers, reaction/RNG state and once-only payments. The JSON defines complete states, failure/retry, cargo/equipment effects and acceptance cases. Per-field reported/derived/estimated labels remain visible; a surrogate is not a recovered historical model. Ordinary cargo and mission lots must survive permitted ship changes or block them when capacity cannot fit.

For implementation, use the common project flight units and O08 weapon readers, plus these explicit mission overrides. A source value always takes precedence over an estimate. The original Elite missions here are ship-based; no walking, SRV or Frontier mission system is required.
