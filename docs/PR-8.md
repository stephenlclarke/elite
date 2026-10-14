# PR #8: TOML missions and signed macOS release

The Constrictor hunt, Thargoid plans delivery and Blackjack's Bullion now load their campaign stages, conditions, dialogs, clues, encounter bindings and rewards from bundled TOMLs. Commander > Install Mission Pack accepts supported external content without rebuilding. The optional Lave courier example reserves one tonne and pays 50 CR exactly once at Zaonce.

The engine validates IDs, versions, capabilities, references, conditions/actions and file bounds; it rejects scripts, unsafe file types and unsupported mechanics. GameRuntime owns installation and simulation changes. Transitions commit the commander, payloads, stage and receipts atomically. Read adapters map all legacy naval/Blackjack stages without rewriting old saves or replacing unique targets. Missing or changed packs suspend saved progress and cargo. External target spawning, repeatable contract instances, calendar time, cabins, crew and storage remain unsupported; researched packets stay queued.

The app exposes installed/suspended campaigns in its Gallery, scrolls long dialogs and lists reserved parcels in inventory. The window now presents a completed Retina frame atomically, correcting partial native redraws. Status/inventory use contextual Back/help footers consistently. Static-analysis cleanup removes nested conditional expressions and an unused parameter from the previous shipyard change.

A Makefile-backed distribution workflow builds arm64+x86_64 Release slices, packages exact resources/notices and signs with Developer ID and the hardened runtime. It verifies the extracted ZIP, records its source checkpoint/checksum and separates signing from notarization. The packaged download and actual signing status will be recorded before this PR is marked ready.

## Validation

Native review installed the external example in the already-built app, accepted it at Lave, flew to Zaonce, completed actual automatic docking, paid exactly 500 tenths of CR and restored Complete after save/reload. Eight compact captures after the redraw fix retained all text; wide Gallery review passed. The original user commander and save preference were restored. Local evidence: reports/ui/mission-pack-audit/report.md.

Final local make ci passes 219 Swift tests and nine Python checks, with 92.53% line coverage, clean Thread Sanitizer (70.2s), clean Address Sanitizer (316.8s) and zero detected leaks. This includes all original naval/Blackjack scenarios, external install/validation/save migration/atomic reward cases, gallery reset and long-dialog bounds. Signed package provenance will be recorded before publication. Player documentation: [MISSION-PACKS.md](MISSION-PACKS.md), [MACOS-DISTRIBUTION.md](MACOS-DISTRIBUTION.md). Motivation: [ISSUE-8.md](ISSUE-8.md).
