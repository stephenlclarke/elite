# test: align startup trial and trading expectations with approved native behavior

## Change and rationale

Executive demo/pause/options checks now independently expect Rowan Calder,7200 tenths, SH025/full130 at galaxy0/system7 before and after game-over input. Demo timing, title/status navigation, pause/control options, equipment and validity assertions remain intact.

The two callers of freshNativeResetScriptState are both included. The helper now builds empty mission state plus a new-commander calendar and exactly one genuine original-main resource at the fixed main-station-v1:main-orbital:0:7 namespace. Station energy comes from the authenticated Hull.station native combat source with the same100 fallback as SpaceBody; destruction remains false. NativeMainStationIdentity binds the fresh owner's unpredictable UUID, fixed system and deterministic resource, and each caller checks the entire mainStations collection against that independent identity. No resource values or script state are copied from observed output. Full live/saved script-state and commander equality, native validity, old-owner replacement, clear cargo, failed-writer rollback, controls, bytes, generation and cold reload checks remain mandatory.

The four trial scenarios use an independent resource matrix: declared scene means SH023/fuel70/cash100000; absent scene means SH025/fuel130/cash7200. Pledges in either scenario are affordable; only declared-scene couriers are acceptable for the fixed listings used here. The no-scene courier deadline refusal remains exact, and the no-scene pledge quote must retain7200 before cash and5000 donation. All canonical equipment/provenance/missile/identity/stale-quote/save/reload/restart/return and live-file isolation checks remain unchanged.

AutoTrader independently captures arrival bids for existing cargo revenue and asks for subsequent purchases. The full cash-plus-sale-minus-refuel-minus-new-freight equation, positive profit, capacity, funds, in-flight refusal, stranded-fuel and secret auto-trade checks are retained. No game behavior, startup data, authored scenarios or spread changes.

## Exact scope and qualification

- executiveDefaultsDemoAndPauseOptions: one case.
- gameOverReturnReplacesBoundDurableSaveWithClearedNativeCommander: one case.
- failedGameOverResetRestoresNativeStateControlsAndOriginalSaveBytes: one additional Root-authorized shared-helper consumer; source-proven stale expectations, not a recorded39943 failure.
- publishedTrialQuotesBindCanonicalEquipmentAcrossSaveLoadRestartAndReturn(scenario:): four cases, the complete pledge/scene Boolean matrix.
- autoTraderUsesEconomyCapitalAndCargo: one case.

Five methods/eight declared cases address thirteen recorded issues in four methods plus the adjacent source-proven helper consumer. The old shared helper had exactly two callers; both are included, with no further helper consumers or unrelated path changes. One coherent independent complete-method/helper bugs/performance/style review precedes G1's matching warm build and only this selection. Scoped strict formatting, Markdown lint, whitespace and source/oracle conservation checks precede freeze. No author compiler/build/test/probe/native runtime execution.

Runtime qualification, hosted acceptance, global review/quality gates and release remain pending. Prior failures and the unattributed SIGBUS remain retained, with no crash fix claim. Root/G1 own central ledger and integration; G2's first prerequisite batch stays frozen and unrelated cohorts are not repeated. See [motivation](ISSUE-hosted399-startup-market-expectations.md).
