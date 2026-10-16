# feat(pledges): confirm complete station donations with retained local standing

Station Aid adds six voluntary station offers: 500/1500/3000 CR or 1/3/5 tonnes Food. Donate transfers the complete actual resource amount, increments standing for the offering provider/main station, retains a typed receipt and completes the assignment in one durable proposal. Back is initially selected and changes no property.

A closed pledge declaration fixes native terms. Candidate-only admission binds the real accepted event, offer, content, station, epoch and quoted resources. Completion requires the matching native receipt; missing, delayed, faulting or later commands roll back the whole proposal. Standing retains its complete bounded receipt history across hull/content changes. Format20 uses the existing save chunks; old format claims and raw unversioned Commander files cannot conceal new pledge evidence, while genuine legacy saves remain readable.

Board keyboard, pointer and menu actions use successful last-painted identity and viewport checks. Trials open an isolated unaccepted review, and completed Gallery rows show human CR/Food/provider/standing details. Trial scene construction now returns before full board preparation; Start, Restart and standalone trials prepare their private candidate synchronously before saving or publishing runtime state. The existing fully prepared convenience API remains compatible.

Validation passed on frozen source/media `51cb55617a2e8dd21fddde6e67b425ee978a7bdd`:

- Fresh uninterrupted `make ci`: 615 methods/692 case invocations in each coverage, thread sanitizer and serial address sanitizer lane; 95.1419% overall line coverage, 99.0909% added-source line coverage, zero leaks. Total monotonic command time 880.592s. All 789 tested inputs and all 899 tracked frozen hashes stayed unchanged.
- Focused source `f70a6a2870bc2dd09221faa3a6bfa591864e56e1`: exact failed trial under ASan, all 21 native methods under ASan, and 204 core methods/269 cases passed. Actual Start/NSMenu Restart and preparation/save failure atomicity are covered. Researcher independently verified source hashes, results and original images.
- Actual `make ships` rendered all 168 ships; only input fingerprints changed. `make readme-media` regenerated identical media/icon bytes. Fourteen fresh original UI captures remain byte-identical to the inspected set; ten durable originals accompany the evidence.

[The validation record](MISSION-CODER-G21-VALIDATION.json) retains commands, commits, monotonic phase timings, coverage, frozen hashes and all five failed ASan archives. The unsuccessful loop/pure-completion/context experiments were removed; the final source retains the shared finish and two-phase trial boundary. No test, quote, stack or sanitizer shortcut was used. Three independently reproduced base formatting diagnostics remain outside this source scope; changed Markdown passed.

Compatibility and scope: standing, amounts and loaded/unpaused-hour cadence are explicit project policies, without historical/server parity claims. Actual native sellable Food is authoritative; protected payloads and passenger hold remain separate. No finance, wallet, faction privileges, parallel save infrastructure or Food reservation subsystem is added.

Request: [ISSUE-station-donation.md](ISSUE-station-donation.md). API and original images: [STATION-PLEDGES.md](STATION-PLEDGES.md). Researcher closed canonical source/media/test acceptance; final handoff integrity/local integration, actual PR `@codex review` until clean and final-head checks remain with the Orchestrator/central integrator. Nothing has been independently pushed or merged.
